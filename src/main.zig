const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
});

const window_width = 640;
const window_height = 400;

// playable grid
const grid_spacing = 10;
const boundary_thickness = 10;
const playable_width = window_width - 2 * boundary_thickness;
const playable_height = window_height - 2 * boundary_thickness;
const grid_width = playable_width / grid_spacing;
const grid_height = playable_height / grid_spacing;

const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

const GridPoint = struct {
    x: u8 = 0,
    y: u8 = 0,
};

const Pixel = struct {
    x: u16,
    y: u16,
};

fn gridPointToPixel(gp: GridPoint) Pixel {
    const pixel: Pixel = .{
        .x = @as(u16, gp.x) * grid_spacing + boundary_thickness,
        .y = @as(u16, gp.y) * grid_spacing + boundary_thickness,
    };
    return pixel;
}

const Cell = enum {
    head,
    body,
    tail,
    food,
    empty,
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
    var snake_direction:Direction = .east;
    var grid : [grid_height][grid_width]Cell = undefined;
    for (grid) |*row| {
        for (row) |*cell| {
            cell.* = .empty;
        }
    }
    grid[5][5] = .food;
    grid[10][10] = .head;
    grid[10][9] = .tail;

    var frame: usize = 0;
    mainloop: while (true) {
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                else => {},
            }
        }

        // background color
        const background_color = Color{ .r = 0xaf, .g = 0xaf, .b = 0xaf, .a = 0xff };
        _ = c.SDL_SetRenderDrawColor(renderer, background_color.r, background_color.g, background_color.b, background_color.a);
        _ = c.SDL_RenderClear(renderer);

        // boundary of game
        const boundary_color = Color{ .r = 0x7f, .g = 0x3f, .b = 0x3f, .a = 0xff };
        const boundary_left = c.SDL_Rect{ .x = 0, .y = 0, .w = boundary_thickness, .h = window_height };
        const boundary_top = c.SDL_Rect{ .x = 0, .y = 0, .w = window_width, .h = boundary_thickness };
        const boundary_bottom = c.SDL_Rect{ .x = window_width - boundary_thickness, .y = 0, .w = boundary_thickness, .h = window_height };
        const boundary_right = c.SDL_Rect{ .x = 0, .y = window_height - boundary_thickness, .w = window_width, .h = boundary_thickness };
        _ = c.SDL_SetRenderDrawColor(renderer, boundary_color.r, boundary_color.g, boundary_color.b, boundary_color.a);
        _ = c.SDL_RenderFillRect(renderer, &boundary_left);
        _ = c.SDL_RenderFillRect(renderer, &boundary_top);
        _ = c.SDL_RenderFillRect(renderer, &boundary_bottom);
        _ = c.SDL_RenderFillRect(renderer, &boundary_right);

        // draw grid lines
        const draw_grid = true;
        if (draw_grid) {
            const grid_color = Color{ .r = 0x2f, .g = 0x2f, .b = 0x2f, .a = 0xff };
            _ = c.SDL_SetRenderDrawColor(renderer, grid_color.r, grid_color.g, grid_color.b, grid_color.a);
            {
                var x: u8 = 0;
                while (x <= grid_width) : (x += 1) {
                    const pixel = gridPointToPixel(.{ .x = x, .y = 0 });
                    const line = c.SDL_Rect{ .x = pixel.x, .y = pixel.y, .w = 1, .h = playable_height };
                    _ = c.SDL_RenderFillRect(renderer, &line);
                }
            }
            {
                var y: u8 = 0;
                while (y <= grid_height) : (y += 1) {
                    const pixel = gridPointToPixel(.{ .x = 0, .y = y });
                    const line = c.SDL_Rect{ .x = pixel.x, .y = pixel.y, .w = playable_width, .h = 1 };
                    _ = c.SDL_RenderFillRect(renderer, &line);
                }
            }
        }

        // update game state
        var next_head_y: i8 = undefined;
        var next_head_x: i8 = undefined;
//         var next_tail_y: i8 = undefined;
//         var next_tail_x: i8 = undefined;
        for (grid) |*row, j| {
            for (row) |*cell, i| {
                const y = @intCast(i8,@truncate(u7, j));
                const x = @intCast(i8,@truncate(u7, i));
                switch(cell.*) {
                    .head => switch (snake_direction) {
                        .north => {
                            next_head_x = x;
                            next_head_y = y - 1;
                        },
                        .east => {
                            next_head_x = x + 1;
                            next_head_y = y;
                        },
                        .south => {
                            next_head_x = x;
                            next_head_y = y+1;
                        },
                        .west => {
                            next_head_x = x - 1;
                            next_head_y = y;
                        },
                    },
                    else => {},
                }
            }
        }

        // draw game state
        const snake_color = Color{ .r=0x2f, .g=0x8f, .b=0x2f, .a=0xff };
        const food_color = Color{ .r=0x8f, .g=0x2f, .b=0x2f, .a=0xff };
        for (grid) |row, y| {
            for (row) |cell, x| {
                const gp = GridPoint{.x=@truncate(u8,x), .y=@truncate(u8,y)};
                const pixel = gridPointToPixel(gp);
                switch (cell) {
                    .head,.body,.tail => {
                        const snake_rect = c.SDL_Rect{ .x = pixel.x, .y=pixel.y, .w=grid_spacing+1, .h=grid_spacing+1 };
                        _ = c.SDL_SetRenderDrawColor(renderer, snake_color.r, snake_color.g, snake_color.b, snake_color.a);
                        _ = c.SDL_RenderFillRect(renderer, &snake_rect);
                    },
                    .food => {
                        const food_rect = c.SDL_Rect{ .x = pixel.x, .y=pixel.y, .w=grid_spacing+1, .h=grid_spacing+1 };
                        _ = c.SDL_SetRenderDrawColor(renderer, food_color.r, food_color.g, food_color.b, food_color.a);
                        _ = c.SDL_RenderFillRect(renderer, &food_rect);
                    },
                    .empty => {},
                }
            }
        }

        c.SDL_RenderPresent(renderer);
        frame += 1;
    }
}
