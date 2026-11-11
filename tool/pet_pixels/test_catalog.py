from pathlib import Path
import unittest

from catalog import load_catalog, render_animations
from sprite_source import render_grid


ROOT = Path(__file__).resolve().parents[2]


class CatalogTest(unittest.TestCase):
    def test_existing_pets_have_complete_contoured_connected_frames(self):
        palette, pets = load_catalog(ROOT / 'assets/pet_sources')
        self.assertEqual(set(pets), {p.stem for p in (ROOT / 'assets/pets').glob('*.png')})
        self.assertEqual(palette['K'], (47, 47, 46, 255))
        for name, spec in pets.items():
            animations = render_animations(spec)
            self.assertEqual([a.row for a in animations], list(range(10)))
            for animation in animations:
                with self.subTest(pet=name, action=animation.name):
                    self.assertEqual(len(animation.grids), 8)
                    for grid in animation.grids:
                        image = render_grid(grid, palette)
                        occupied = {(x, y) for y in range(32) for x in range(32)
                                    if grid[y][x] != '.'}
                        visited = {next(iter(occupied))}
                        frontier = list(visited)
                        while frontier:
                            x, y = frontier.pop()
                            for dx in (-1, 0, 1):
                                for dy in (-1, 0, 1):
                                    point = (x + dx, y + dy)
                                    if point in occupied and point not in visited:
                                        visited.add(point)
                                        frontier.append(point)
                        self.assertEqual(visited, occupied, 'Detached pixels or body parts')
                        for x, y in occupied:
                            if any((x + dx, y + dy) not in occupied
                                   for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                                self.assertEqual(grid[y][x], 'K', 'Broken silhouette outline')
                        if animation.row not in (5, 8):
                            self.assertEqual(image.getbbox()[3], 29, 'Ground jitter')

    def test_idle_and_sleep_do_not_morph_and_cycles_close_smoothly(self):
        _, pets = load_catalog(ROOT / 'assets/pet_sources')
        for name, spec in pets.items():
            for animation in render_animations(spec):
                grids = animation.grids
                areas = [sum(c != '.' for row in grid for c in row) for grid in grids]
                with self.subTest(pet=name, action=animation.name):
                    self.assertGreater(len({tuple(grid) for grid in grids}), 1, 'Frozen animation')
                    if animation.row in (0, 6):
                        self.assertLessEqual(max(areas) - min(areas), max(areas) * .10)
                    # Include the loop seam: an otherwise smooth row can still snap on replay.
                    pixels = [{(x, y, color) for y, row in enumerate(grid)
                               for x, color in enumerate(row) if color != '.'} for grid in grids]
                    for index, current in enumerate(pixels):
                        previous = pixels[index - 1]
                        # Exclude intentional travel/jumps, but retain silhouette and color drift.
                        changed = min(max(len(current - moved), len(moved - current))
                                      for dx in range(-2, 3) for dy in range(-2, 3)
                                      if (moved := {(x + dx, y + dy, c) for x, y, c in previous}))
                        self.assertLessEqual(changed, max(areas) * .40)


if __name__ == '__main__':
    unittest.main()
