use image::codecs::pnm::PnmDecoder;
use image::DynamicImage;
use image::Rgb;
use std::fs::File;
use std::io::BufReader;
use std::io::Write;

const COLS: usize = 25;
const ROWS: usize = 40;
const WIDTH: usize = 2500;
const HEIGHT: usize = 2000;
const GRID_CELL_WIDTH: usize = WIDTH / COLS;
const GRID_CELL_HEIGHT: usize = HEIGHT / ROWS;

fn main() {
    let args = std::env::args().into_iter().collect::<Vec<String>>();

    let from = &args[1];
    let to = &args[2];

    let from = File::open(from).unwrap();
    let from = BufReader::new(from);
    let from = PnmDecoder::new(from).unwrap();

    let to = File::open(to).unwrap();
    let to = BufReader::new(to);
    let to = PnmDecoder::new(to).unwrap();

    let from = DynamicImage::from_decoder(from).unwrap().to_rgb8();
    let to = DynamicImage::from_decoder(to).unwrap().to_rgb8();

    let mut output: Vec<Vec<(i32, i32, i32)>> = (0..1000)
        .map(|_| (0..5000).map(|_account| (0, 0, 0)).collect())
        .collect();

    from.enumerate_pixels().zip(to.enumerate_pixels()).for_each(
        |((x, y, Rgb([fr, fg, fb])), (_, _, Rgb([tr, tg, tb])))| {
            let grid_row = y as usize / GRID_CELL_HEIGHT;
            let grid_col = x as usize / GRID_CELL_WIDTH;
            let rollup_row = y as usize % GRID_CELL_HEIGHT;
            let rollup_col = x as usize % GRID_CELL_WIDTH;
            let account = rollup_col + (rollup_row * GRID_CELL_WIDTH);
            let rollup = grid_col + (grid_row * COLS);

            output[rollup][account] = (
                normalize(*tr as i32, *fr as i32),
                normalize(*tg as i32, *fg as i32),
                normalize(*tb as i32, *fb as i32),
            );
        },
    );

    for (rollup, diffs) in output.iter().enumerate() {
        let mut f = File::create(format!("./output/rollup{}.diff", rollup)).unwrap();

        for (account, (red_diff, green_diff, blue_diff)) in diffs.iter().enumerate() {
            writeln!(f, "{},{},{},{}", account, red_diff, green_diff, blue_diff).unwrap();
        }
    }
}

fn normalize(t: i32, f: i32) -> i32 {
    if t == f {
        if t == 255 {
            t - 1
        } else {
            t + 1
        }
    } else {
        t - f
    }
}
