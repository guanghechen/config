use super::*;

#[test]
fn t_matches_canonical_normalize() {
    let cases = [
        "",
        "/workspace/./src/../file.lua",
        r"C:\workspace\.\src\..\file.lua",
        r"\\server\share\folder\..\file.lua",
        r"folder\literal.lua",
    ];

    for os_path in cases {
        for keep_tailing_slash in [false, true] {
            assert_eq!(
                from_os_path(os_path, keep_tailing_slash),
                normalize(os_path, keep_tailing_slash),
                "os_path={os_path:?}"
            );
        }
    }
}
