# Rust 中的智能指针(Smart Pointers)

在 Rust 中,smart pointer 是一类行为类似指针、但额外携带元数据与能力的数据结构。它们负责管理内存、所有权以及其他资源,提供比普通引用更丰富的功能。它们是 Rust 所有权系统的重要组成部分,让程序在没有垃圾回收器的情况下也能实现安全的内存管理。

下面是 Rust 中几种最常见的 smart pointer:

## 1. `Box<T>`(堆分配)

*   **用途:** 让你把数据存放在 heap 上而非 stack 上。当 `Box` 离开作用域时,其析构函数会运行,heap 上的内存随之被释放。
*   **特性:**
    *   **单一所有权:** `Box` 独占它所指向数据的所有权。
    *   **在 stack 上大小固定:** `Box` 本身是位于 stack 上的一个指针,而它所指向的数据位于 heap 上。这对于编译期无法确定大小的类型(例如递归类型)非常有用,或者当你有大量数据、直接放在 stack 上会导致栈溢出时也很有用。
*   **适用场景:**
    *   当某个类型的大小在编译期无法确定,而你又想在一个需要确切大小的上下文中使用该类型的值时。
    *   当你有大量数据,并希望在不复制数据的前提下转移其所有权时。
    *   当你想拥有一个 trait object 时(例如 `Box<dyn Trait>`)。

```rust
fn main() {
    let b = Box::new(5); // 'b' 是一个 Box,指向 heap 上的整数 5
    println!("b = {}", b);

    // 递归数据结构的示例(类似链表)
    enum List {
        Cons(i32, Box<List>),
        Nil,
    }
    let list = List::Cons(1, Box::new(List::Cons(2, Box::new(List::Nil))));
}
```

## 2. `Rc<T>`(引用计数,reference counting)

*   **用途:** 支持数据的多重所有权。`Rc` 是 "reference counting"(引用计数)的缩写。当存在多个所有者时,只有当最后一个所有者离开作用域时,数据才会被清理。
*   **特性:**
    *   **多个不可变所有者:** 允许代码的多个部分拥有同一份数据,但通过 `Rc<T>` 访问的数据本身是不可变的。
    *   **单线程:** 只能在单个线程内使用,不能安全地跨线程共享。
    *   **运行时开销:** 引用计数在运行时更新,会带来少量性能成本。
*   **适用场景:**
    *   当你需要在程序的多个部分之间共享数据,并且确定这些数据只会在单个线程中被访问时。
    *   图(graph)数据结构中,多个节点可能指向同一份数据的场景。

```rust
use std::rc::Rc;

fn main() {
    let five = Rc::new(5);
    let five_clone = Rc::clone(&five); // 增加引用计数
    let five_another = Rc::clone(&five);

    println!("Reference count: {}", Rc::strong_count(&five)); // 输出: 3

    // 当最后一个 Rc 离开作用域时,数据被 drop
    drop(five_clone);
    println!("Reference count after drop: {}", Rc::strong_count(&five)); // 输出: 2
}
```

## 3. `Arc<T>`(原子引用计数,atomic reference counting)

*   **用途:** 与 `Rc<T>` 类似,但提供线程安全的多重所有权。`Arc` 是 "atomic reference counting"(原子引用计数)的缩写。
*   **特性:**
    *   **多个不可变所有者:** 允许代码的多个部分拥有同一份数据。
    *   **多线程(线程安全):** 可以安全地跨多个线程共享。
    *   **更高的运行时开销:** 使用原子操作进行引用计数,这比非原子操作更慢,但对于线程安全是必需的。
*   **适用场景:**
    *   当你需要在多个线程之间共享数据时。

```rust
use std::sync::Arc;
use std::thread;

fn main() {
    let five = Arc::new(5);
    let five_clone = Arc::clone(&five);

    let handle = thread::spawn(move || {
        println!("Value from thread: {}", five_clone);
    });

    handle.join().unwrap();
    println!("Value from main: {}", five);
}
```

## 4. `RefCell<T>`(内部可变性,interior mutability)

*   **用途:** 允许你在只持有数据所有者的不可变引用时,仍然修改该数据。这被称为"内部可变性(interior mutability)"。
*   **特性:**
    *   **单线程:** 只能在单个线程内使用。
    *   **运行时借用检查:** 在运行时强制执行 Rust 的借用规则,一旦违反规则就会 panic。
    *   **通过不可变引用进行可变借用:** 支持这样一种场景:你需要修改一份原本被不可变借用的数据(例如位于 `Rc<T>` 之中的数据)。
*   **适用场景:**
    *   当你需要修改 `Rc<T>` 内部的数据时。
    *   当某个数据结构从外部看逻辑上是不可变的,但仍需要更新其内部状态时(例如缓存)。

```rust
use std::cell::RefCell;

fn main() {
    let x = RefCell::new(vec![1, 2, 3]);
    let y = &x; // 对 RefCell 的不可变引用

    // 我们仍然可以通过不可变引用 'y' 修改内部的 vector
    y.borrow_mut().push(4);

    println!("{:?}", x.borrow()); // 输出: [1, 2, 3, 4]
}
```

## 5. `Cell<T>`(面向 `Copy` 类型的内部可变性)

*   **用途:** 与 `RefCell<T>` 类似,但专门用于实现了 `Copy` trait 的类型。它通过替换整个值来实现 interior mutability。
*   **特性:**
    *   **单线程:** 只能在单个线程内使用。
    *   **无运行时借用检查:** 由于它只适用于 `Copy` 类型,因此不需要运行时借用检查;它只是直接替换值。
*   **适用场景:**
    *   当你需要为小型 `Copy` 类型(如整数、布尔值、字符)实现 interior mutability 时。

```rust
use std::cell::Cell;

fn main() {
    let x = Cell::new(5);
    let y = &x; // 对 Cell 的不可变引用

    y.set(10); // 修改内部的值

    println!("Value: {}", x.get()); // 输出: 10
}
```

## 6. `Weak<T>`(非所有权引用)

*   **用途:** 与 `Rc<T>`(或 `Arc<T>`)配合使用,用于创建非所有权引用。这对于打破 reference cycle 至关重要,否则这类循环会导致内存泄漏。
*   **特性:**
    *   **非所有权:** 不会增加它所指向的 `Rc<T>` 的引用计数。
    *   **可以被升级:** 如果数据仍然存在,可以将其升级为 `Rc<T>`(或 `Arc<T>`)。如果数据已经被 drop,`upgrade()` 会返回 `None`。
*   **适用场景:**
    *   在树状数据结构中实现父子关系:子节点拥有父节点,但父节点不拥有子节点(以避免 reference cycle)。

```rust
use std::rc::{Rc, Weak};

struct Node {
    value: i32,
    parent: Option<Weak<Node>>,
    children: RefCell<Vec<Rc<Node>>>, // 用 RefCell 实现 children 的 interior mutability
}

fn main() {
    let leaf = Rc::new(Node {
        value: 3,
        parent: None,
        children: RefCell::new(vec![]),
    });

    let branch = Rc::new(Node {
        value: 5,
        parent: Some(Rc::downgrade(&leaf)), // 父节点是一个 Weak 引用
        children: RefCell::new(vec![Rc::clone(&leaf)]),
    });

    // 现在,让 leaf 的父节点指向 branch
    // 如果 'parent' 的类型是 Rc<Node>,这会形成一个 reference cycle
    // leaf.parent = Some(Rc::downgrade(&branch)); // 如果取消注释、且 parent 为 Rc,这一行会造成 reference cycle

    println!("Leaf parent: {:?}", leaf.parent.as_ref().and_then(|w| w.upgrade()).map(|n| n.value));
    println!("Branch parent: {:?}", branch.parent.as_ref().and_then(|w| w.upgrade()).map(|n| n.value));
}
```
