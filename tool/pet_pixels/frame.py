def blank():
    return [list('.' * 32) for _ in range(32)]


def stamp(grid, part, x=0, y=0):
    for dy, row in enumerate(part):
        for dx, pixel in enumerate(row):
            if pixel == '.':
                continue
            px, py = x + dx, y + dy
            if not 1 <= px <= 30 or not 1 <= py <= 30:
                raise ValueError(f'Pose would clip a pixel at ({px}, {py})')
            grid[py][px] = pixel


def shifted(grid, dx=0, dy=0):
    result = blank()
    stamp(result, grid, dx, dy)
    return result


def ground(grid):
    bottom = max(y for y, row in enumerate(grid) if any(c != '.' for c in row))
    return shifted(grid, dy=28 - bottom)


def contour(grid):
    result = [row.copy() for row in grid]
    for y in range(1, 31):
        for x in range(1, 31):
            if grid[y][x] != '.' and any(grid[y + dy][x + dx] == '.'
                                       for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                result[y][x] = 'K'
    return [''.join(row) for row in result]


def blink(part, eyes, fill):
    result = [list(row) for row in part]
    for x, y in eyes:
        result[y][x] = fill
    columns = sorted({x for x, _ in eyes})
    groups = []
    for x in columns:
        if not groups or x > groups[-1][-1] + 1:
            groups.append([])
        groups[-1].append(x)
    for group in groups:
        y = max(y for x, y in eyes if x in group)
        for x in range(group[0], max(group[-1] + 1, group[0] + 2)):
            result[y][x] = 'K'
    return result


def lean(part, amount, pivot=28):
    result = blank()
    top = min(y for y, row in enumerate(part) if any(pixel != '.' for pixel in row))
    extent = max(1, pivot - top)
    for y, row in enumerate(part):
        stamp(result, [row], round(amount * (pivot - y) / extent), y)
    return result


def look(part, eyes, fill, dx):
    result = [list(row) for row in part]
    for x, y in eyes:
        result[y][x] = fill
    for x, y in eyes:
        result[y][x + dx] = 'K'
    return result
