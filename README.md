# kbuilder

A lightweight and flexible Bash script to build Linux kernels with support for custom LLVM toolchains.

## 📦 Features

- 🔧 Default or custom Clang-based toolchain support (`--custom_tc=path`)
- 📁 Custom defconfig support (`--defconfig=config_name`)
- 🧹 Clean build directory (`clean`)
- ⚙️ Build and compile kernel (`build`)
- 🧠 Colorful CLI output and helpful messages
- 🐧 Default `ARCH` set to `x86`, customizable inside script

---

## 🧪 Requirements

- `clang`, `llvm-*` tools (or custom toolchain)
- GNU `make`
- Optional: `ccache` for faster rebuilds

---

## 🚀 Usage

```bash
./kbuilder [options]
```

### 🔧 Commands

| Command   | Description                         |
|-----------|-------------------------------------|
| `clean`   | Cleans the kernel build directory   |
| `build`   | Starts building the kernel          |

> ⚠️ `clean` must be first, and `build` must be last if used.

### 🛠️ Options

| Option               | Description                                          |
|----------------------|------------------------------------------------------|
| `--custom_tc=PATH`   | Use custom LLVM toolchain from specified directory   |
| `--defconfig=NAME`   | Use a specific defconfig file (e.g., `my_defconfig`) |
| `-v`, `--version`    | Show version and license                            |
| `-h`, `--help`       | Show help message                                   |

---

## 📂 Example

```bash
./kbuilder clean --custom_tc=~/toolchains/clang-r450784d build
```

kbuilder can also be ran without actually downloading the script:

```bash
bash <(curl -s "https://raw.githubusercontent.com/liquidprjkt/liquid_kernel_builder/refs/heads/main/kbuilder.sh") build
```

---

## 📜 License

This project is licensed under the GNU GPL v3. See [LICENSE](https://www.gnu.org/licenses/gpl-3.0.html) for details.

---

## 👤 Author

**UsiFX**  
📧 xprjkts@gmail.com  
💻 GitHub: [UsiFX](https://github.com/UsiFX)
