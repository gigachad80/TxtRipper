
🚀 Project Name : TxtRipper
===============

![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-purple.svg)
<a href="https://github.com/gigachad80/TxtRipper/issues"><img src="https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat"></a>

#### Fetches robots.txt content from single URLs or a list, follows redirects, handles errors, and allows filtering for Disallow directives.

---

### 📌 Overview

 *_TxtRipper_* This Ruby script is a utility to fetch the robots.txt file from a given domain or a list. It automatically attempts both HTTP and HTTPS, follows redirects, and includes error handling for network issues. The script can display the full robots.txt content or filter Disallow paths, which can be used for directory brute forcing or fuzzing 

### 🤔 Why This Name?

Initially, it was Roboto, but I wanted to give it a different name , so I choose TxtRipper (as it's related to `robots.txt`).

### ⌚ Total Time Taken to Develop & Test
1 hr 31 min 44 sec for v2

### 🙃 Why I Created This

I developed this script to automate the process of retrieving robots.txt files from websites directly from terminal instead manually checking each domain , following redirects, and extracting specific rules like Disallow which can be time-consuming, especially for multiple targets. This tool provides a simple, programmatic way to fetch the content reliably and easily extract key information needed for analysis or integration into other automated tasks like bruteforcing directories or bypass 403

### 📚 Requirements & Dependencies

* Ruby (latest version recommended)
* Target website / Scope of your bug hunting

### ⚡ Quick Installation & Usage

1.  Git clone this repo:
    ```bash
    git clone https://github.com/gigachad80/TxtRipper
    cd TxtRipper
    ```
2.  Type `ruby TxtRipper.rb -h` to see options.
3.  Check given options and use it on your target.

### Demo Syntax : 
```
ruby TxtRipper.rb -u example.com ( Fetch all contents of robots.txt from target website )
```
```
ruby TxtRipper.rb -u example.com -d ( Fetch only Disallowed paths )
```
```
ruby TxtRipper.rb -u example.com -d -f -n --brute ( Fetch all Diallowed paths for bruteforcing ).
```

```
ruby TxtRipper.rb -u example.com -d -f ( Fetch only Disallow paths and prints output with https to show full URL , no need to add https or adding disallow paths before target. Just click them ).
```

### 📝 Roadmap / To-do

-   [ ] Bypass 403 integration
-   [x] Integration of different directory brute forcing tools
-   [x] Add Demo syntax to use 

### 💓 Credits:

* Thanks to Defronix for inspiration 

### 📞 Contact

**📧 Email:** pookielinuxuser@tutamail.com

### 📄 License

Licensed under **GNU General Public License 3.0**

---

**🕒 Last Updated:** June 6, 2025
