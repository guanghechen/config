# Rust Data Types

Rust 是一门静态类型语言,这意味着它必须在编译期就知道所有变量的类型。不过,编译器通常足够智能,能够推断出类型,因此你并不总是需要显式写出它们。

Rust 的数据类型大致可以分为以下几类:

## 1. Scalar Types

scalar type(标量类型)表示单个值。

*   **整数(Integers):**
    *   有符号:`i8`、`i16`、`i32`、`i64`、`i128`(可存储负数或正数)
    *   无符号:`u8`、`u16`、`u32`、`u64`、`u128`(只能存储正数)
    *   与架构相关:`isize`、`usize`(指针大小,通常为 32 位或 64 位)
    *   *示例:* `let x: i32 = 42;`

*   **浮点数(Floating-Point Numbers):**
    *   `f32`(单精度)
    *   `f64`(双精度,默认)
    *   *示例:* `let pi: f64 = 3.14159;`

*   **布尔值(Booleans):**
    *   `bool`(取值为 `true` 或 `false`)
    *   *示例:* `let is_rust_fun: bool = true;`

*   **字符(Characters):**
    *   `char`(表示单个 Unicode 标量值,大小为 4 字节)
    *   *示例:* `let initial: char = 'R';`

## 2. Compound Types

compound type(复合类型)可以将多个值组合为一个类型。

*   **元组(Tuples):**
    *   一种通用方式,用于将若干个不同类型的值组合成一个复合类型。
    *   长度固定。
    *   *示例:* `let person: (&str, i32, bool) = ("Alice", 30, true);`

*   **数组(Arrays):**
    *   一组*相同类型*值的集合。
    *   长度固定。
    *   存储在栈上。
    *   *示例:* `let numbers: [i32; 5] = [1, 2, 3, 4, 5];`

*   **切片(Slices):**
    *   对某个集合(如 array 或 `Vec`)中一段连续元素的引用。
    *   它们不拥有所有权。
    *   *示例:* `let a = [1, 2, 3, 4, 5]; let slice = &a[1..4];`

## 3. User-Defined Types

这些类型由程序员自行定义。

*   **结构体(Structs):**
    *   自定义的数据结构,允许你为多个相关的值命名并将其打包在一起。
    *   *示例:*
        ```rust
        struct Point {
            x: i32,
            y: i32,
        }
        let origin = Point { x: 0, y: 0 };
        ```

*   **枚举(Enums):**
    *   允许你通过列举一个类型所有可能的变体(variant)来定义它。变体可以携带数据。
    *   *示例:*
        ```rust
        enum TrafficLight {
            Red,
            Yellow,
            Green,
        }
        let light = TrafficLight::Red;
        ```

*   **联合体(Unions):**
    *   类似于 C 的 union,允许多个字段占用同一块内存位置。
    *   使用是 **unsafe** 的,主要用于 FFI。
    *   *示例:*
        ```rust
        #[repr(C)]
        union MyUnion {
            i: u32,
            f: f32,
        }
        // 使用时需要 `unsafe` 块。
        ```

## 4. Pointers and References

Rust 使用引用(reference)在不获取所有权的前提下借用值。raw pointer(裸指针)则用于 unsafe 操作。

*   **引用(References):**
    *   `&T`:不可变引用(只读访问)。
    *   `&mut T`:可变引用(读写访问)。
    *   *示例:* `let mut s = String::from("hello"); let r1 = &s; let r2 = &mut s;`(注意:由于借用规则,`r1` 与 `r2` 不能在同一作用域内共存)。

*   **裸指针(Raw Pointers):**
    *   `*const T`:不可变 raw pointer。
    *   `*mut T`:可变 raw pointer。
    *   解引用是 **unsafe** 的,用于 FFI 或高度优化的代码。
    *   *示例:* `let num = 5; let r = &num as *const i32;`

## 5. String Types

Rust 有两种主要的字符串类型。

*   **字符串切片(`&str`):**
    *   对一段 UTF-8 编码字符串数据的不可变视图。
    *   常用于字符串字面量,或对 `String` 某一部分的引用。
    *   *示例:* `let hello: &str = "Hello, world!";`

*   **持有所有权的字符串(`String`):**
    *   一种可增长、可变、拥有所有权的 UTF-8 编码字符串类型。
    *   存储在堆上。
    *   *示例:* `let mut s = String::from("hello"); s.push_str(", world!");`

## 6. Other Important Types

以下并非原始类型(primitive type),但它们是 Rust 编程的基础。

*   **单元类型 unit type(`()`):**
    *   表示不存在任何值。
    *   常用作那些没有有意义返回值的函数的返回类型。
    *   *示例:* `fn do_nothing() -> () { /* ... */ }`

*   **never type(`!`):**
    *   表示一段永远不会完成的计算(例如,总是 panic 或无限循环的函数)。
    *   *示例:* `fn forever() -> ! { loop {} }`

*   **Option(`Option<T>`):**
    *   一个 enum,表示某个值可能存在(`Some(T)`)或不存在(`None`)。
    *   用于安全地处理空值的可能性。
    *   *示例:* `let some_number = Some(5); let no_number: Option<i32> = None;`

*   **Result(`Result<T, E>`):**
    *   一个 enum,表示一个可能失败的操作:要么成功(`Ok(T)`)并携带一个值,要么失败(`Err(E)`)并携带一个错误。
    *   用于错误处理。
    *   *示例:* `let file_result = File::open("foo.txt");`

*   **Box(`Box<T>`):**
    *   一种智能指针,在堆上分配数据。
    *   用于递归数据结构,或当你需要将某个值存储在堆上时。
    *   *示例:* `let b = Box::new(5);`

*   **引用计数(`Rc<T>`、`Arc<T>`):**
    *   `Rc<T>`:在单线程内对堆上数据的多重所有权。
    *   `Arc<T>`:原子引用计数,用于跨多个线程的多重所有权。
    *   *示例:* `let a = Rc::new(String::from("test")); let b = Rc::clone(&a);`

*   **内部可变性(`Cell<T>`、`RefCell<T>`):**
    *   这类类型允许你即便持有对外层类型的不可变引用,也能修改其中的数据。
    *   `Cell<T>`:用于实现了 `Copy` 的类型。
    *   `RefCell<T>`:用于未实现 `Copy` 的类型,在运行时检查借用规则。
    *   *示例:* `let c = RefCell::new(vec![1, 2, 3]);`

以上列表涵盖了 Rust 中最常见、最基础的数据类型。

---

## Tuple Destructuring

在 Rust 中,你可以对 tuple 进行解构(destructuring),将其中各个值分别提取到独立的变量中。这是处理 tuple 数据时一种非常常见且便捷的方式。

以下是解构 tuple 的几种主要方法:

### 1. 使用 `let` 进行基础解构

最常见的方式是使用 `let` 语句,配合一个与 tuple 结构相匹配的模式(pattern)。

```rust
fn main() {
    let person_data = ("Alice", 30, true);

    // 将 tuple 解构为三个独立的变量
    let (name, age, is_active) = person_data;

    println!("Name: {}", name);
    println!("Age: {}", age);
    println!("Is Active: {}", is_active);

    // 你也可以在创建 tuple 时直接解构
    let (x, y) = (10, 20);
    println!("x: {}, y: {}", x, y);
}
```

### 2. 按索引访问元素(并非解构,但相关)

虽然这不算解构,但你始终可以使用点号(`.`)加索引(从 0 开始)来访问 tuple 的各个元素。

```rust
fn main() {
    let coordinates = (100, 200, 300);

    let x = coordinates.0;
    let y = coordinates.1;
    let z = coordinates.2;

    println!("X: {}, Y: {}, Z: {}", x, y, z);
}
```

### 3. 解构时忽略某些元素

在解构时,你可以用下划线(`_`)代替变量名,从而忽略 tuple 中的特定元素。

```rust
fn main() {
    let product_info = ("Laptop", 1200.00, 15, "Electronics");

    // 解构,但只提取名称和价格,忽略数量和类别
    let (product_name, price, _, _) = product_info;

    println!("Product: {}", product_name);
    println!("Price: ${}", price);
}
```

### 4. 在函数参数中解构

你可以直接在函数参数列表中解构 tuple,这样在处理 tuple 输入时能让函数签名更简洁。

```rust
fn print_point((x, y): (i32, i32)) {
    println!("Point coordinates: ({}, {})", x, y);
}

fn main() {
    let my_point = (50, 75);
    print_point(my_point);

    // 你也可以传入一个字面量 tuple
    print_point((10, 20));
}
```

### 5. 使用 `match` 表达式进行解构

对于更复杂的模式匹配,尤其是处理嵌套 tuple 或包含 tuple 的 enum 时,`match` 表达式非常强大。

```rust
fn process_status(status: (u32, &str)) {
    match status {
        (200, "OK") => println!("Request successful!"),
        (404, "Not Found") => println!("Error: Resource not found."),
        (code, message) => println!("Unhandled status: {} - {}", code, message),
    }
}

fn main() {
    process_status((200, "OK"));
    process_status((404, "Not Found"));
    process_status((500, "Internal Server Error"));
}
```
