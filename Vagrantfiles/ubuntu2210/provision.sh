#!/bin/bash

# Ensures that ansible-core is installed
# https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html

# Ensure .local/bin is in the PATH
if ! grep -q ".local/bin" ~/.bashrc
then
    echo "export PATH=~/.local/bin:$PATH" >> ~/.bashrc
    source ~/.bashrc
fi

# Ensure pip3 is present
if ! python3 -m pip -V &> /dev/null
then
    echo "Installing pip3"
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python3 get-pip.py --user
    rm get-pip.py
fi

# Ensure ansible is present
if ! ansible --version &> /dev/null
then
    echo "Installing ansible"
    python3 -m pip install --user ansible
fi