This repo allows you to checkout a local or a remote git branch even if you have lots of uncommitted changes. It does it by stashing, checking out and unstashing your local changes.

Requirements:
- ruby installed
- git (tested on version 2.21.0)

Install:
- clone the repository
- install [bundler](https://bundler.io) if you haven't already 
- run ```bundle install``` (it may require root privileges to install the requirements on the global libs path)

Run:
- from inside a git repository, run the main.rb script (it does'nt matter where it's located) - ```ruby /path/to/this/repo/main.rb```
- I recommand giving this script an alias using the .bashrc file or in any other way so it'll be easy to run everywhere

Example print screen:
![alt text](https://raw.githubusercontent.com/itay235711/terminal_smart_checkout/master/screenshots/usage.png)
