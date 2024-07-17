use uuid::Uuid;

pub fn uuid((): ()) -> String {
    let uuid = Uuid::new_v4();
    uuid.to_string()
}
