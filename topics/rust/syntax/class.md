# Rust 中的"类"

Rust 并没有像 C++、Java 或 Python 那样的 `class` 关键字。取而代之的是,它提供了一组强大的特性组合,让你能够以一种略有不同但非常高效的方式实现面向对象编程(OOP)的目标。其核心组成部分是 **`struct`**、**`impl`** 块和 **`trait`**。

---

## 1. Struct:定义数据

`struct`(结构体)用于把相关的数据聚合在一起,相当于类的字段(field)或属性。

```rust
// 定义一个名为 Circle 的 struct,包含一个公开字段 'radius'。
pub struct Circle {
    pub radius: f64,
}
```

在这个示例中,`Circle` 是一个只持有一份数据的 struct:`radius`。`pub` 关键字使 `radius` 字段可以在定义 `Circle` 的模块之外被访问。

---

## 2. `impl` 块:实现行为

`impl`(implementation,实现)块用于定义与 struct 关联的函数和 method。你的"类"的行为(method)就存放在这里。

```rust
// Circle struct 的实现块
impl Circle {
    // 一个充当构造函数的 "associated function"。
    // 按照惯例将其命名为 'new'。它不属于某个具体的实例,
    // 而是属于 struct 类型本身。
    pub fn new(radius: f64) -> Self {
        Self { radius }
    }

    // 一个作用于 struct 实例的 "method"。
    // 第一个参数总是 `self`、`&self` 或 `&mut self`。
    // `&self` 是对该实例的不可变引用。
    pub fn area(&self) -> f64 {
        std::f64::consts::PI * self.radius * self.radius
    }
}
```

### 组合运用:实例化与使用

现在你可以像使用类对象一样创建和使用 `Circle` 的实例。

```rust
fn main() {
    // 使用 associated function 'new' 创建一个新实例。
    let my_circle = Circle::new(5.0);

    // 在该实例上调用 'area' method。
    println!("The area of the circle is: {}", my_circle.area());

    // 直接访问公开字段。
    println!("The radius is: {}", my_circle.radius);
}
```

---

## 3. Trait:共享行为与接口

`trait` 是 Rust 用来在不同 struct 之间定义共享行为的机制,类似于其他语言中的 `interface`(接口)。trait 支持一种形式的 polymorphism(多态)。

下面定义一个 `Shape` trait,要求任何实现它的类型都必须提供 `area` method。

```rust
// 为任何具有面积的形状定义一个 trait。
pub trait Shape {
    fn area(&self) -> f64;
}

// 现在,我们再定义另一个 struct。
pub struct Rectangle {
    pub width: f64,
    pub height: f64,
}

// 为 Rectangle 实现 Shape trait。
impl Shape for Rectangle {
    fn area(&self) -> f64 {
        self.width * self.height
    }
}

// 我们还需要为 Circle 实现它。
// 假设我们已经有了 Circle struct 及其 impl 块。
// 我们可以再新增一个 impl 块来实现该 trait。
impl Shape for Circle {
    fn area(&self) -> f64 {
        std::f64::consts::PI * self.radius * self.radius
    }
}
```

现在你可以编写接受任意实现了 `Shape` trait 的类型的函数:

```rust
// 这个函数可以接受任意实现了 Shape trait 的类型。
fn print_area(shape: &impl Shape) {
    println!("This shape has an area of: {}", shape.area());
}

fn main() {
    let circle = Circle { radius: 10.0 };
    let rectangle = Rectangle { width: 3.0, height: 4.0 };

    print_area(&circle);      // 适用于 Circle
    print_area(&rectangle);   // 适用于 Rectangle
}
```

---

## Rust 中的继承(组合与 trait)

Rust 没有 Java 或 C++ 等面向对象语言中那种直接的类 inheritance(继承)概念。相反,Rust 鼓励用不同的模式来实现代码复用和 polymorphism:**composition(组合)** 和 **trait**。

### Composition(组合)

Composition 是通过组合更简单的类型来构建复杂类型的做法。struct 不是从基类继承,而是可以包含其他 struct 的实例。

```rust
// 一个基础组件
pub struct Engine {
    pub horsepower: u32,
}

impl Engine {
    pub fn new(horsepower: u32) -> Self {
        Engine { horsepower }
    }

    pub fn start(&self) {
        println!("Engine with {} HP started!");
    }
}

// 一个 "has-a"(组合)了 Engine 的 struct
pub struct Car {
    pub make: String,
    pub model: String,
    pub engine: Engine, // Car "拥有一个"(has-a)Engine
}

impl Car {
    pub fn new(make: String, model: String, horsepower: u32) -> Self {
        Car {
            make,
            model,
            engine: Engine::new(horsepower),
        }
    }

    pub fn drive(&self) {
        println!("Driving a {} {}...", self.make, self.model);
        self.engine.start(); // 将行为委托给被组合的 Engine
    }
}

fn main() {
    let my_car = Car::new(String::from("Toyota"), String::from("Camry"), 150);
    my_car.drive();
}
```
在这个示例中,`Car` 并不继承自 `Engine`,而是 *包含* 一个 `Engine`。`Car` 将 `start` 行为委托给它的 `engine` 字段。

### 用 Trait 实现 Polymorphism

正如前面所讨论的,trait 提供了一种定义共享行为(接口)的方式,不同类型都可以去实现它。这使得无需 inheritance 即可实现 polymorphism。

---

## Encapsulation(封装,公开与私有的 method/字段)

Rust 使用其 **模块系统** 来控制各项(函数、struct、enum、method、字段)的可见性(公开或私有)。默认情况下,Rust 中的一切对其所在模块而言都是 **私有的**。

### `pub` 关键字

要让某一项公开、可从其所在模块之外访问,需要使用 `pub` 关键字。

```rust
// 在类似 `src/lib.rs` 或 `src/main.rs` 的文件中

mod my_module {
    // 这个 struct 是公开的,因此可以在 `my_module` 之外使用。
    pub struct MyStruct {
        // 这个字段是公开的,因此可以被直接访问。
        pub public_field: i32,
        // 这个字段默认是私有的。
        private_field: String,
    }

    impl MyStruct {
        // 这个 associated function(构造函数)是公开的。
        pub fn new(public_val: i32, private_val: String) -> Self {
            MyStruct {
                public_field: public_val,
                private_field: private_val,
            }
        }

        // 这个 method 是公开的。
        pub fn get_private_field(&self) -> &str {
            &self.private_field
        }

        // 这个 method 默认是私有的。
        fn internal_logic(&self) {
            println!("Running internal logic.");
        }
    }

    // 这个函数是公开的。
    pub fn public_function() {
        println!("This is a public function.");
    }

    // 这个函数默认是私有的。
    fn private_function() {
        println!("This is a private function.");
    }
}

fn main() {
    use my_module::MyStruct;
    use my_module::public_function;

    let instance = MyStruct::new(10, String::from("secret"));

    println!("Public field: {}", instance.public_field);
    // println!("Private field: {}", instance.private_field); // 错误:`private_field` 是私有的

    println!("Private field via public method: {}", instance.get_private_field());

    public_function();
    // my_module::private_function(); // 错误:`private_function` 是私有的
}
```

### Encapsulation 要点:

*   **默认私有:** 除非显式标记为 `pub`,否则一切都是私有的。
*   **粒度控制:** 你可以在模块、struct、字段、enum 以及函数/method 层级上控制可见性。
*   **`pub(crate)`:** 使某一项在当前 crate 内公开,但对外部 crate 保持私有。
*   **`pub(super)`:** 使某一项对父模块公开。
*   **`pub(in path)`:** 使某一项在指定路径范围内公开。

这套机制支持强 encapsulation,确保模块或类型的内部实现细节可以在不影响使用它的外部代码的前提下被修改。

## 总结

| OOP 概念            | Rust 对应实现                          | 说明                                                    |
|---------------------|----------------------------------------|---------------------------------------------------------|
| **类**              | `struct` + `impl`                      | struct 持有数据;impl 块定义其 method。                 |
| **字段**            | `struct` 字段                          | 属于某个对象的变量。                                    |
| **方法**            | `impl` 块中的函数                      | 作用于对象实例(`&self`)的函数。                       |
| **构造函数**        | associated function(惯例名为 `new`)   | 创建并返回新实例的函数。                                |
| **静态方法**        | associated function                    | 与类型关联、而非与具体实例关联的函数。                  |
| **接口**            | `trait`                                | 定义一个类型必须实现的一组 method。                     |
| **继承**            | composition 与 trait(无直接继承)     | Rust 更倾向于通过 trait 组合功能,而非类 inheritance。  |
| **封装**            | 模块系统(`pub`)                      | 默认情况下,字段和 method 对其所在模块保持私有。        |

Rust 的这套做法鼓励组合优于继承(composition over inheritance),并借助类型系统和编译器来保证内存安全、避免传统 OOP 语言中常见的 bug。
