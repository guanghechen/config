use super::super::SEP;
use super::super::get_cwd;
use super::super::join;
use super::super::resolve;
use super::is_descendant;

#[test]
fn t_is_descendant_is_case_sensitive() {
    let from = "C:\\Repo";
    let to = "c:/repo/child";

    assert!(!is_descendant(from, to));
}

#[test]
fn t_is_descendant_cases() {
    #[derive(Clone, Copy)]
    enum IPathKey {
        Base,
        AbsSrc,
        AbsSrcUtils,
        AbsOther,
        RelSrc,
        RelUtils,
        RelUtilsDeep,
        Literal(&'static str),
    }

    struct IPathSet {
        base: String,
        abs_src: String,
        abs_src_utils: String,
        abs_other: String,
        rel_src: String,
        rel_utils: String,
        rel_utils_deep: String,
    }

    impl IPathSet {
        fn from_base(base: String) -> Self {
            let abs_src = resolve(&base, "src", false, SEP);
            let abs_src_utils = resolve(&abs_src, "utils", false, SEP);
            let abs_other = resolve(&base, "other", false, SEP);
            let rel_src = "src".to_string();
            let rel_utils = join(&rel_src, "utils", false, SEP);
            let rel_utils_deep = join(&rel_utils, "deep", false, SEP);

            Self {
                base,
                abs_src,
                abs_src_utils,
                abs_other,
                rel_src,
                rel_utils,
                rel_utils_deep,
            }
        }

        fn materialize(&self, key: IPathKey) -> String {
            match key {
                IPathKey::Base => self.base.clone(),
                IPathKey::AbsSrc => self.abs_src.clone(),
                IPathKey::AbsSrcUtils => self.abs_src_utils.clone(),
                IPathKey::AbsOther => self.abs_other.clone(),
                IPathKey::RelSrc => self.rel_src.clone(),
                IPathKey::RelUtils => self.rel_utils.clone(),
                IPathKey::RelUtilsDeep => self.rel_utils_deep.clone(),
                IPathKey::Literal(value) => value.to_string(),
            }
        }
    }

    const CASES: &[(IPathKey, IPathKey, bool)] = &[
        (IPathKey::Base, IPathKey::AbsSrc, true),
        (IPathKey::Base, IPathKey::Base, true),
        (IPathKey::AbsSrc, IPathKey::AbsSrcUtils, true),
        (IPathKey::AbsSrc, IPathKey::AbsOther, false),
        (IPathKey::AbsSrcUtils, IPathKey::AbsSrc, false),
        (IPathKey::AbsSrc, IPathKey::Base, false),
        (IPathKey::RelSrc, IPathKey::RelSrc, true),
        (IPathKey::RelSrc, IPathKey::RelUtils, true),
        (IPathKey::RelUtils, IPathKey::RelSrc, false),
        (IPathKey::RelSrc, IPathKey::Literal("other"), false),
        (IPathKey::RelSrc, IPathKey::AbsSrcUtils, true),
        (IPathKey::RelSrc, IPathKey::AbsOther, false),
        (IPathKey::AbsSrc, IPathKey::RelSrc, true),
        (IPathKey::Base, IPathKey::RelUtilsDeep, true),
        (IPathKey::Literal(".."), IPathKey::RelSrc, true),
        (IPathKey::Literal(".."), IPathKey::AbsOther, true),
        (IPathKey::AbsOther, IPathKey::Literal(".."), false),
        (IPathKey::RelSrc, IPathKey::Literal("../src"), false),
    ];

    for &(from_key, to_key, expected) in CASES {
        const MAX_ATTEMPTS: usize = 8;
        let mut attempt = 0;
        loop {
            attempt += 1;
            let base_before = get_cwd().to_string();
            let paths = IPathSet::from_base(base_before.clone());
            let from = paths.materialize(from_key);
            let to = paths.materialize(to_key);
            let actual = is_descendant(&from, &to);
            let base_after = get_cwd().to_string();
            if base_after == base_before {
                assert_eq!(actual, expected, "from: {from}, to: {to}");
                break;
            }
            if attempt >= MAX_ATTEMPTS {
                panic!("cwd changed during assertion: before={base_before}, after={base_after}");
            }
        }
    }
}
