from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile


class PackageArchiveTests(unittest.TestCase):
    @unittest.skipUnless(sys.platform == "darwin", "macOS extended attributes")
    def test_extended_attributes_do_not_add_unsigned_zip_entries(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            package = root / "example.duckpad-plugin"
            package.mkdir()
            payload = {"plugin.json": b"{}", "module.dylib": b"signed module",
                       "SHA256SUMS": b"inventory", "SIGNATURE.ed25519": b"signature"}
            for name, data in payload.items():
                (package / name).write_bytes(data)
                subprocess.run(["xattr", "-w", "com.duckpad.packaging-test", "metadata", str(package / name)], check=True)
            output = root / "plugin.zip"
            script = Path(__file__).resolve().parents[1] / "scripts/archive.py"
            subprocess.run([sys.executable, str(script), str(package), str(output)], check=True)
            with zipfile.ZipFile(output) as archive:
                entries = {item.filename: archive.read(item) for item in archive.infolist() if not item.is_dir()}
                self.assertEqual(entries, {f"{package.name}/{name}": data for name, data in payload.items()})
            attribute = subprocess.check_output(["xattr", "-p", "com.duckpad.packaging-test", str(package / "module.dylib")])
            self.assertEqual(attribute.strip(), b"metadata")
            original = output.read_bytes()
            result = subprocess.run([sys.executable, str(script), str(package), str(output)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(output.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
