import argparse
from pathlib import Path

from PIL import Image

from preview import write_previews
from catalog import load_catalog, render_animations
from sprite_source import render_grid


def export_catalog(source, destination, previews=None):
    palette, pets = load_catalog(source)
    rendered = {name: [(a, [render_grid(g, palette) for g in a.grids])
                       for a in render_animations(spec)] for name, spec in pets.items()}
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    for name, animations in rendered.items():
        sheet = Image.new('RGBA', (512, 640))
        native_animations = []
        for animation, frames in animations:
            native_frames = []
            for column, frame in enumerate(frames):
                # Each logical pixel becomes a crisp 2x2 block; never interpolate.
                native = frame.resize((64, 64), Image.Resampling.NEAREST)
                native_frames.append(native)
                sheet.paste(native, (column * 64, animation.row * 64))
            native_animations.append((animation, native_frames))
        sheet.save(destination / f'{name}.png')
        if previews:
            folder = Path(previews) / name
            folder.mkdir(parents=True, exist_ok=True)
            write_previews(native_animations, palette, folder)


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description='Rebuild existing pets from ASCII parts (requires Pillow).')
    parser.add_argument('--source', type=Path, default=root / 'assets/pet_sources')
    parser.add_argument('--output', type=Path, default=root / 'assets/pets')
    parser.add_argument('--previews', type=Path)
    args = parser.parse_args()
    try:
        export_catalog(args.source, args.output, args.previews)
    except (ValueError, OSError, KeyError, TypeError, IndexError) as error:
        parser.exit(1, f'Invalid sprite source: {error}\n')
    print(f'Rebuilt existing pet sheets in {args.output}')
