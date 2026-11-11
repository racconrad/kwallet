from pathlib import Path
import tempfile
import unittest

from PIL import Image

from export import export_catalog


SOURCE = Path(__file__).resolve().parents[2] / 'assets/pet_sources'


class ExportTest(unittest.TestCase):
    def test_rebuilds_all_existing_sheets_without_empty_animation_rows(self):
        with tempfile.TemporaryDirectory() as tmp:
            export_catalog(SOURCE, Path(tmp))
            self.assertEqual(len(list(Path(tmp).glob('*.png'))), 14)
            for sheet in Path(tmp).glob('*.png'):
                self.assertEqual(sheet.read_bytes(), (SOURCE.parent / 'pets' / sheet.name).read_bytes(),
                                 f'{sheet.name}: bundled asset is stale')
            with Image.open(Path(tmp) / 'cat.png') as image:
                self.assertEqual(image.size, (512, 640))
                self.assertEqual(image.mode, 'RGBA')
                self.assertEqual(image.getpixel((24, 32)), (47, 47, 46, 255))
                for row in range(10):
                    for frame in range(8):
                        self.assertIsNotNone(image.crop((frame * 64, row * 64,
                                                        frame * 64 + 64, row * 64 + 64)).getbbox())
                self.assertEqual({alpha for _, alpha in image.getchannel('A').getcolors()}, {0, 255})
                logical = image.resize((256, 320), Image.Resampling.NEAREST)
                self.assertEqual(logical.resize((512, 640), Image.Resampling.NEAREST).tobytes(),
                                 image.tobytes(), 'Coarse reference pixel grid must stay uniform')

    def test_exports_are_byte_reproducible_and_gifs_preserve_cycle_timing(self):
        with tempfile.TemporaryDirectory() as tmp:
            a, b = Path(tmp) / 'a', Path(tmp) / 'b'
            export_catalog(SOURCE, a)
            export_catalog(SOURCE, b)
            self.assertEqual({p.name: p.read_bytes() for p in a.iterdir()},
                             {p.name: p.read_bytes() for p in b.iterdir()})
            previews = Path(tmp) / 'previews'
            export_catalog(SOURCE, a, previews)
            for name, duration in [('idle', 1920), ('walk', 960)]:
                with Image.open(previews / 'cat' / f'{name}.gif') as image:
                    self.assertEqual(image.info['loop'], 0)
                    total = 0
                    poses = set()
                    for index in range(image.n_frames):
                        image.seek(index)
                        total += image.info['duration']
                        poses.add(image.convert('RGB').tobytes())
                    self.assertEqual(total, duration)
                    self.assertGreater(len(poses), 1)


if __name__ == '__main__':
    unittest.main()
