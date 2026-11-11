import unittest

from sprite_source import render_grid, validate_palette


PALETTE = {'.': None, 'K': '#302c35', 'F': '#e7a66a'}


def standing_grid():
    rows = ['.' * 32 for _ in range(32)]
    rows[27] = '.' * 15 + 'KF' + '.' * 15
    rows[28] = '.' * 15 + 'KK' + '.' * 15
    return rows


class SpriteSourceTest(unittest.TestCase):
    def test_character_mapping_preserves_exact_rgba_and_transparency(self):
        image = render_grid(standing_grid(), validate_palette(PALETTE))
        self.assertEqual(image.size, (32, 32))
        self.assertEqual(image.getpixel((16, 27)), (231, 166, 106, 255))
        self.assertEqual(image.getpixel((15, 27)), (48, 44, 53, 255))
        self.assertEqual(image.getpixel((0, 0)), (0, 0, 0, 0))

    def test_rejects_undefined_characters_ragged_rows_and_clipped_pixels(self):
        palette = validate_palette(PALETTE)
        for row, value in [(27, 'x' + '.' * 31), (27, '.' * 31),
                           (0, '.' * 15 + 'K' + '.' * 16)]:
            with self.subTest(row=row, value=value):
                grid = standing_grid()
                grid[row] = value
                with self.assertRaises(ValueError):
                    render_grid(grid, palette)
        with self.assertRaises(ValueError):
            render_grid(standing_grid()[:-1], palette)
        with self.assertRaises(ValueError):
            render_grid(['.' * 32] * 32, palette)

    def test_rejects_invalid_palette_and_partial_alpha(self):
        invalid = [dict(PALETTE, F='#fff'), dict(PALETTE, F='#e7a66a80'),
                   dict(PALETTE, FF='#ffffff'), dict(PALETTE, K=None),
                   dict(PALETTE, **{'.': '#000000'})]
        for palette in invalid:
            with self.subTest(palette=palette), self.assertRaises(ValueError):
                validate_palette(palette)
        with self.assertRaises(ValueError):
            validate_palette({'.': None, **{chr(65 + i): '#ffffff' for i in range(17)}})


if __name__ == '__main__':
    unittest.main()
