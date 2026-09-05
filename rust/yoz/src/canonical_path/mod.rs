mod basename;
mod cwd;
mod dirname;
mod extname;
mod from_os_path;
mod is_absolute;
mod is_descendant;
mod is_dirpath;
mod join;
mod normalize;
mod relative;
mod resolve;
mod sep;
mod split;
mod to_os_path;

pub use basename::*;
pub use cwd::*;
pub use dirname::*;
pub use extname::*;
pub use from_os_path::*;
pub use is_absolute::*;
pub use is_descendant::*;
pub use is_dirpath::*;
pub use join::*;
pub use normalize::*;
pub use relative::*;
pub use resolve::*;
pub use sep::*;
pub use split::*;
pub use to_os_path::*;

#[cfg(test)]
mod differential_tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/canonical_path/differential_test.rs"
    ));
}
