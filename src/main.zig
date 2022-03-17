const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
});

const window_width = 640;
const window_height = 400;

// playable grid
const grid_spacing = 10;
const grid_width = window_width / grid_spacing;
const grid_height = window_height / grid_spacing;

const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

const GridPoint = struct {
    x: u8,
    y: u8,
};

const Pixel = struct {
    x: u16,
    y: u16,
};

fn gridPointToPixel(gp: GridPoint) Pixel {
    const pixel: Pixel = .{
        .x = @as(u16, gp.x) * grid_spacing,
        .y = @as(u16, gp.y) * grid_spacing,
    };
    return pixel;
}

fn pixelToGridPoint(pixel: Pixel) GridPoint {
    const gp: GridPoint = .{
        .x = pixel.x / grid_spacing,
        .y = pixel.y / grid_spacing,
    };
    return gp;
}

const CellType = enum {
    snake,
    food,
    empty,
    wall,
};

const Cell = union(CellType) {
    snake: u16, // distance to head
    food: void,
    empty: void,
    wall: void,
};

const Direction = enum {
    north,
    east,
    south,
    west,
};

pub fn main() anyerror!void {
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    var window = c.SDL_CreateWindow("snake", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, window_width, window_height, 0);
    defer c.SDL_DestroyWindow(window);

    var renderer = c.SDL_CreateRenderer(window, 0, c.SDL_RENDERER_PRESENTVSYNC);
    defer c.SDL_DestroyRenderer(renderer);

    // initial game state
    var snake_direction: Direction = .east;
    var snake_length: u16 = 2;
    var snake_alive: bool = true;
    var grid: [grid_height][grid_width]Cell = undefined;
    for (grid) |*row| {
        for (row) |*cell| {
            cell.* = CellType.empty;
        }
    }
    grid[5][5] = CellType.food;
    grid[10][10] = Cell{ .snake = 0 };
    grid[10][9] = Cell{ .snake = 1 };
    // boundary
    for (grid[0]) |*top_cell| {
        top_cell.* = .wall;
    }
    for (grid[grid_height - 1]) |*bottom_cell| {
        bottom_cell.* = .wall;
    }
    for (grid) |*row| {
        row[0] = .wall;
        row[grid_width - 1] = .wall;
    }

    var frame: usize = 0;
    mainloop: while (true) {
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                else => {},
            }
        }

        // initialize next game state
        var grid_next: [grid_height][grid_width]Cell = undefined;
        for (grid_next) |*row| {
            for (row) |*cell| {
                cell.* = CellType.empty;
            }
        }

        // calculate next game state
        for (grid) |row, y| {
            for (row) |cell, x| {
                switch (cell) {
                    .snake => |distance_to_head| {
                        grid_next[y][x] = Cell{ .snake = distance_to_head + 1 };
                        if (distance_to_head == 0) switch (snake_direction) {
                            // Assumes head coordinate is >0 and <grid_width-1 or grid_height-1 (aka not already in wall)
                            .north => {
                                grid_next[y - 1][x] = Cell{ .snake = 0 };
                            },
                            .east => {
                                grid_next[y][x + 1] = Cell{ .snake = 0 };
                            },
                            .south => {
                                grid_next[y + 1][x] = Cell{ .snake = 0 };
                            },
                            .west => {
                                grid_next[y][x - 1] = Cell{ .snake = 0 };
                            },
                        };
                        if (distance_to_head + 1 >= snake_length) grid_next[y][x] = CellType.empty;
                    },
                    .wall, .food => grid_next[y][x] = cell,
                    else => {},
                }
            }
        }

        // Search for collisions with head
        for (grid_next) |row, y| {
            for (row) |cell_next, x| {
                const cell = grid[y][x];
                switch (cell_next) {
                    .snake => |distance_to_head| {
                        if (distance_to_head == 0) switch (cell) {
                            .wall, .snake => snake_alive = false,
                            else => {},
                        };
                    },
                    else => {},
                }
            }
        }

        // store next game state into current game state
        if (snake_alive) {
            for (grid) |*row, y| {
                for (row) |*cell, x| {
                    cell.* = grid_next[y][x];
                }
            }
        }

        // background color
        const background_color = Color{ .r = 0xaf, .g = 0xaf, .b = 0xaf, .a = 0xff };
        _ = c.SDL_SetRenderDrawColor(renderer, background_color.r, background_color.g, background_color.b, background_color.a);
        _ = c.SDL_RenderClear(renderer);

        // draw grid lines
        const draw_grid = true;
        if (draw_grid) {
            const grid_color = Color{ .r = 0x2f, .g = 0x2f, .b = 0x2f, .a = 0xff };
            _ = c.SDL_SetRenderDrawColor(renderer, grid_color.r, grid_color.g, grid_color.b, grid_color.a);
            {
                var x: u8 = 0;
                while (x < grid_width) : (x += 1) {
                    const pixel = gridPointToPixel(.{ .x = x, .y = 0 });
                    const line = c.SDL_Rect{ .x = pixel.x, .y = pixel.y, .w = 1, .h = window_height };
                    _ = c.SDL_RenderFillRect(renderer, &line);
                }
            }
            {
                var y: u8 = 0;
                while (y < grid_height) : (y += 1) {
                    const pixel = gridPointToPixel(.{ .x = 0, .y = y });
                    const line = c.SDL_Rect{ .x = pixel.x, .y = pixel.y, .w = window_width, .h = 1 };
                    _ = c.SDL_RenderFillRect(renderer, &line);
                }
            }
        }

        // draw game state
        const snake_color = Color{ .r = 0x2f, .g = 0x8f, .b = 0x2f, .a = 0xff };
        const food_color = Color{ .r = 0x8f, .g = 0x2f, .b = 0x2f, .a = 0xff };
        const wall_color = Color{ .r = 0x7f, .g = 0x3f, .b = 0x3f, .a = 0xff };
        for (grid) |row, y| {
            for (row) |cell, x| {
                const gp = GridPoint{ .x = @truncate(u8, x), .y = @truncate(u8, y) };
                const pixel = gridPointToPixel(gp);
                switch (cell) {
                    .snake => {
                        const snake_rect = c.SDL_Rect{ .x = pixel.x, .y = pixel.y, .w = grid_spacing + 1, .h = grid_spacing + 1 };
                        _ = c.SDL_SetRenderDrawColor(renderer, snake_color.r, snake_color.g, snake_color.b, snake_color.a);
                        _ = c.SDL_RenderFillRect(renderer, &snake_rect);
                    },
                    .food => {
                        const food_rect = c.SDL_Rect{ .x = pixel.x, .y = pixel.y, .w = grid_spacing + 1, .h = grid_spacing + 1 };
                        _ = c.SDL_SetRenderDrawColor(renderer, food_color.r, food_color.g, food_color.b, food_color.a);
                        _ = c.SDL_RenderFillRect(renderer, &food_rect);
                    },
                    .wall => {
                        const wall_rect = c.SDL_Rect{ .x = pixel.x, .y = pixel.y, .w = grid_spacing + 1, .h = grid_spacing + 1 };
                        _ = c.SDL_SetRenderDrawColor(renderer, wall_color.r, wall_color.g, wall_color.b, wall_color.a);
                        _ = c.SDL_RenderFillRect(renderer, &wall_rect);
                    },
                    .empty => {},
                }
            }
        }

        c.SDL_RenderPresent(renderer);
        frame += 1;
    }
}
