
🚀 Project Name : TxtRipper
===============

![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-purple.svg)
<a href="https://github.com/gigachad80/grep-backURLs/issues"><img src="https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat"></a>

#### Fetches robots.txt content from single URLs or a list, follows redirects, handles errors, and allows filtering for Disallow directives.

---

### 📌 Overview

 *_TxtRipper_* This Ruby script is a utility to fetch the robots.txt file from a given domain or a list. It automatically attempts both HTTP and HTTPS, follows redirects, and includes error handling for network issues. The script can display the full robots.txt content or filter specifically for Disallow rules, which 

### 🤔 Why This Name?

Initially, it was Roboto, but I wanted to a different name to give it, so I choose TxtRipper (as it's related to `robots.txt`).

### ⌚ Total Time Taken to Develop & Test

- ### ⌚ Total Time Taken to Build & Test

-   Approx 59 min. Actually, I've developed its first version in 20 min, but it took me this long because there were issues with sites like colgate.com and airtel.in, like **having to implement handling for HTTP redirects (such as 301 and 302), debugging SSL certificate verification failures, and fixing the regex to correctly parse `Disallow:` rules, including those with spaces.**

### 🙃 Why I Created This

I developed this script to automate the process of retrieving robots.txt files from websites. Manually checking each domain , following redirects, and extracting specific rules like Disallow can be time-consuming, especially for multiple targets. This tool provides a simple, programmatic way to fetch the content reliably and easily extract key information needed for analysis or integration into other automated tasks like bruteforcing directories or bypass 403

### 📚 Requirements & Dependencies

* Ruby (latest version recommended)
* Target website / Scope of your bug hunting

### ⚡ Quick Installation & Usage

1.  Git clone this repo:
    ```bash
    git clone [https://github.com/gigachad80/TxtRipper](https://github.com/gigchad80/TxtRipper)
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
ruby TxtRipper.rb -u example.com -d -f ( Fetch only Disallow paths and prints output with https to show full URL , no need to add https or adding disallow paths before target. Just click them ).
```

### 📝 Roadmap / To-do

-   [ ] Bypass 403 integration
-   [ ] Integration of different directory brute forcing tools
-   [ ] Add Demo syntax to use 

### 💓 Credits:

* Defronix

### 📞 Contact

**📧 Email:** pookielinuxuser@tutamail.com

### 📄 License

Licensed under **GNU General Public License 3.0**

---

**🕒 Last Updated:** April 25, 2025
