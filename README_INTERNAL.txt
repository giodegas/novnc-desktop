noVNC Desktop - Usage Guide
===========================

Welcome to the noVNC remote desktop! This guide explains how to use the available applications.

Desktop Access
--------------
The desktop is accessible via browser at: http://localhost:8080

Available Applications
---------------------

Web Browser
-----------
Firefox ESR: Full-featured web browser
  - Open from menu: Right-click on desktop -> Firefox
  - Or from application bar (Firefox icon)
  - Or from terminal: firefox-esr &

Terminal
--------
lxterminal: Graphical terminal
  - Open from menu: Right-click -> Terminal
  - Or from application bar (terminal icon)
  - Or from terminal: lxterminal &

Text Editor
-----------
Vim: Advanced text editor
  - From terminal: vim filename
  - Or from menu: Right-click -> Vim

System Monitoring
-----------------
htop: System resource monitor
  - From terminal: htop
  - Or from menu: Right-click -> Htop

Python and uv
-------------

Python 3
--------
Python 3 is already installed in the system:
  python3 --version
  python3 script.py

uv - Python Package Manager
---------------------------
uv is a fast and modern Python package manager.

Create a virtual environment:
  uv venv
  # or with specific name
  uv venv myenv

Activate the virtual environment:
  source .venv/bin/activate
  # or
  source myenv/bin/activate

Install packages:
  uv pip install package_name
  # or with requirements.txt
  uv pip install -r requirements.txt

Create a new Python project:
  uv init myproject
  cd myproject
  uv add requests  # adds dependency
  uv run python main.py  # runs with managed environment

Practical examples:
  # Create environment and install Flask
  uv venv flask-env
  source flask-env/bin/activate
  uv pip install flask

  # Create new project
  uv init webapp
  cd webapp
  uv add fastapi uvicorn
  uv run python -m uvicorn main:app --host 0.0.0.0

Useful Commands
---------------

File System
-----------
  ls      - List files
  cd      - Change directory
  pwd     - Show current directory
  mkdir   - Create directory
  rm      - Remove file
  cp      - Copy file
  mv      - Move/rename file

Editor
------
  vim filename     - Open with Vim
  nano filename    - Open with Nano (if available)

System
------
  htop    - Resource monitor
  df -h   - Disk space
  free -h - Memory
  ps aux  - Active processes

Important Notes
---------------
- Default user is desktop (not root)
- Home directory is /home/desktop
- Configuration files are in ~/.config/
- For operations requiring privileges, use sudo

Support
-------
For more information on uv: https://docs.astral.sh/uv/
For problems or questions, consult the documentation of individual applications.
