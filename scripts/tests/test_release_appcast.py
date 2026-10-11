from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from generate_appcast import DOWNLOAD_PREFIX, verify_appcast
from release_request import ReleaseError


VERSION = "0.5.0"
DMG_NAME = f"Qili-{VERSION}.dmg"
DMG_BYTES = b"fixture DMG bytes"


def appcast_xml(url, length, signature):
    return f'''<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <item>
            <sparkle:version>{VERSION}</sparkle:version>
            <enclosure url="{url}" length="{length}" type="application/octet-stream"
                       sparkle:edSignature="{signature}"/>
        </item>
    </channel>
</rss>
'''


class AppcastVerificationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.dist = Path(self.temporary.name)
        self.dmg = self.dist / DMG_NAME
        self.dmg.write_bytes(DMG_BYTES)
        self.url = f"{DOWNLOAD_PREFIX}/v{VERSION}/{DMG_NAME}"
        self.signature = "deterministic-ed25519-signature"
        self.appcast = self.dist / "appcast.xml"

    def tearDown(self):
        self.temporary.cleanup()

    def write_appcast(self, url=None, length=None, signature=None):
        self.appcast.write_text(appcast_xml(url or self.url,
                                            len(DMG_BYTES) if length is None else length,
                                            self.signature if signature is None else signature))

    def verify(self):
        return verify_appcast(self.appcast, self.dmg, VERSION, (self.signature, len(DMG_BYTES)))

    def test_valid_appcast_returns_enclosure_url(self):
        self.write_appcast()
        self.assertEqual(self.verify(), self.url)

    def test_version_mismatch_is_rejected(self):
        self.write_appcast()
        with self.assertRaisesRegex(ReleaseError, "version"):
            verify_appcast(self.appcast, self.dmg, "0.5.1", (self.signature, len(DMG_BYTES)))

    def test_wrong_enclosure_url_is_rejected(self):
        self.write_appcast(url="https://evil.example/Qili-0.5.0.dmg")
        with self.assertRaisesRegex(ReleaseError, "URL"):
            self.verify()

    def test_wrong_length_is_rejected(self):
        self.write_appcast(length=len(DMG_BYTES) + 1)
        with self.assertRaisesRegex(ReleaseError, "length"):
            self.verify()

    def test_missing_signature_is_rejected(self):
        self.write_appcast(signature="")
        with self.assertRaisesRegex(ReleaseError, "signature"):
            self.verify()

    def test_signature_mismatch_is_rejected(self):
        self.write_appcast(signature="a-different-signature")
        with self.assertRaisesRegex(ReleaseError, "signature"):
            self.verify()

    def test_multiple_items_are_rejected(self):
        single = appcast_xml(self.url, len(DMG_BYTES), self.signature)
        item = single.split("<item>", 1)[1].split("</item>", 1)[0]
        self.appcast.write_text(single.replace("</channel>", f"<item>{item}</item></channel>"))
        with self.assertRaisesRegex(ReleaseError, "exactly one"):
            self.verify()


if __name__ == "__main__":
    unittest.main()
