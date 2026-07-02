# Rust 关键字

关键字是 Rust 中的保留字,对编译器具有特殊含义。它们不能用作标识符(例如变量名、函数名、结构体名等)。理解关键字是编写正确且地道 Rust 代码的基础。

## 主要关键字(使用中)

这些关键字在 Rust 语法中被实际使用,并承担特定功能。

### 1. 控制流(control flow)

用于管理程序执行流程的关键字。

*   **`if` / `else`**:条件执行。
    ```rust
    fn main() {
        let x = 10;
        if x > 5 {
            println!("x is greater than 5");
        } else {
            println!("x is 5 or less");
        }
    }
    ```
*   **`match`**:用于穷尽性检查的模式匹配(pattern matching)。
    ```rust
    fn main() {
        let x = Some(5);
        match x {
            Some(val) => println!("Got a value: {}", val),
            None => println!("No value"),
        }
    }
    ```
*   **`loop`**:无限循环。
    ```rust
    fn main() {
        let mut count = 0;
        loop {
            count += 1;
            if count == 3 {
                break; // 退出循环
            }
            println!("Looping...");
        }
    }
    ```
*   **`while`**:带条件的循环。
    ```rust
    fn main() {
        let mut num = 3;
        while num != 0 {
            println!("{}!", num);
            num -= 1;
        }
    }
    ```
*   **`for`**:对区间或集合进行迭代。
    ```rust
    fn main() {
        for i in 1..=3 { // 从 1 循环到 3(含 3)
            println!("{}", i);
        }
    }
    ```
*   **`break`**:退出最内层循环。
    *   *注:* 可以从 `loop` 表达式中返回一个值。
*   **`continue`**:跳过当前循环迭代的剩余部分,进入下一次迭代。
*   **`return`**:退出当前函数并返回一个值。
    ```rust
    fn add_one(x: i32) -> i32 {
        return x + 1; // 显式返回
        // x + 1 // 隐式返回(Rust 中的常见写法)
    }
    ```

### 2. 类型与模块

用于定义数据结构、组织代码和管理可见性的关键字。

*   **`struct`**:定义结构体(一种带有具名字段的自定义数据类型)。
    ```rust
    struct Point {
        x: i32,
        y: i32,
    }
    ```
*   **`enum`**:定义枚举(一种可以是多个变体之一的类型)。
    ```rust
    enum Message {
        Quit,
        Move { x: i32, y: i32 },
        Write(String),
    }
    ```
*   **`union`**:定义联合体(类似 C 中的 union,主要用于 FFI(外部函数接口,Foreign Function Interface)和 unsafe 代码)。
    *   *注:* 访问 union 字段是 `unsafe` 的。
*   **`mod`**:声明一个模块,用于将代码组织为命名空间。
    ```rust
    mod my_module {
        fn hello() {
            println!("Hello from my_module!");
        }
    }
    ```
*   **`use`**:将路径(模块、函数、结构体、枚举)引入作用域。
    ```rust
    use std::collections::HashMap;
    ```
*   **`crate`**:指代当前 crate 的根。
*   **`super`**:指代父模块。
*   **`type`**:创建类型别名,或在 trait 中声明关联类型(associated type)。
    ```rust
    type Kilometers = i32; // 类型别名
    ```
*   **`fn`**:声明一个函数。
*   **`trait`**:定义一个 trait(一组类型可以实现的方法集合,类似于接口)。
    ```rust
    trait Summary {
        fn summarize(&self) -> String;
    }
    ```
*   **`impl`**:为某个类型实现一个 trait,或直接在类型上定义方法。
    ```rust
    struct NewsArticle { /* ... */ }
    impl Summary for NewsArticle { /* ... */ } // 实现 trait
    impl NewsArticle { fn new() -> Self { /* ... */ } } // 实现方法
    ```
*   **`extern`**:用于外部函数接口(FFI,Foreign Function Interface),声明由外部语言(如 C)定义的函数或静态变量。
    ```rust
    extern "C" {
        fn abs(input: i32) -> i32;
    }
    ```

### 3. 变量与绑定

与声明变量、管理可变性和所有权相关的关键字。

*   **`let`**:声明一个变量绑定。
    ```rust
    let x = 5;
    ```
*   **`mut`**:使变量绑定或引用可变。
    ```rust
    let mut y = 10;
    y += 1;
    let mut s = String::from("hello");
    let r = &mut s; // 可变引用
    ```
*   **`const`**:声明一个常量。常量必须带有类型标注,且只能被赋值为常量表达式。
    ```rust
    const MAX_POINTS: u32 = 100_000;
    ```
*   **`static`**:声明一个静态变量(在整个程序运行期间存活),或指定 `'static` 生命周期(lifetime)。
    ```rust
    static HELLO_WORLD: &str = "Hello, world!";
    ```
*   **`ref`**:在模式匹配(pattern matching)中使用,用于获取值的引用,而非移动或复制该值。
    ```rust
    let x = 5;
    match x {
        ref r => println!("Got a reference to {}", r),
    }
    ```
*   **`move`**:在闭包中使用,强制闭包取得所捕获变量的所有权。
    ```rust
    let x = vec![1, 2, 3];
    let closure = move || println!("{:?}", x); // x 被移动进闭包
    closure();
    // println!("{:?}", x); // 错误:x 已被移动
    ```

### 4. 可见性

*   **`pub`**:使某个项(函数、结构体、枚举、模块、字段)对外可见。
    ```rust
    pub fn public_function() { /* ... */ }
    ```

### 5. 特殊用途

*   **`as`**:用于类型转换(cast)(例如 `x as f64`),或用于消除 trait 方法的歧义。
*   **`dyn`**:用于 trait 对象(trait object),以启用动态分发(dynamic dispatch)。(在 Rust 2018 版次中引入。)
    ```rust
    trait Draw { fn draw(&self); }
    fn draw_object(obj: &dyn Draw) { obj.draw(); }
    ```
*   **`self`**:指代调用方法时所在的结构体或枚举实例。
*   **`Self`**:指代当前 `impl` 块或 `trait` 的类型。
*   **`unsafe`**:将一段代码块或函数标记为“unsafe”,允许执行 Rust 编译器无法保证内存安全的操作(例如解引用裸指针)。
    *   *注:* 使用 `unsafe` 会将内存安全的责任转移给程序员。
*   **`where`**:为泛型类型参数或生命周期(lifetime)参数指定额外的约束。
    ```rust
    fn print_debug<T>(item: T) where T: Debug {
        println!("{:?}", item);
    }
    ```

### 6. 布尔字面量

*   **`true`**:布尔值“真”。
*   **`false`**:布尔值“假”。

### 7. 异步编程(Rust 2018 版次及以后)

*   **`async`**:用于定义返回 `Future` 的异步函数。
    ```rust
    async fn fetch_data() -> String { /* ... */ }
    ```
*   **`await`**:用于暂停 `async` 函数的执行,直到某个 `Future` 完成。
    ```rust
    async fn main() {
        let data = fetch_data().await;
        println!("{}", data);
    }
    ```

## 保留关键字(留作将来使用)

这些词被 Rust 编译器保留,不能用作标识符,尽管它们目前在语言中并没有具体含义。保留它们是为了将来可能的语言扩展。

*   `abstract`
*   `become`
*   `box`
*   `do`
*   `final`
*   `macro`
*   `override`
*   `priv`
*   `try`
*   `typeof`
*   `unsized`
*   `virtual`
*   `yield`

## 重要提示

*   **不能用作标识符:** 最关键的规则是,你不能将这些关键字中的任何一个用作变量、函数、类型、模块等的名称。
*   **版次相关的关键字:** 某些关键字如 `async`、`await` 和 `dyn` 是在 Rust 2018 版次中引入的。较旧的版次可能无法识别它们,或以不同的方式处理它们。
*   **上下文关键字(contextual keywords):** 虽然 Rust 通常拥有严格的关键字,但某些结构可能*看起来*像关键字,实际上在特定上下文中却是标识符(例如 `union` 在成为关键字之前,或 trait 实现中的 `default`)。不过,最好避免使用任何形似关键字的词,以防混淆。
