# Use the official Ubuntu image as a base
FROM ubuntu:latest

# Update package list and install necessary packages
RUN apt update && apt install -y sudo curl wget

# Create a new user with a password and home directory
RUN useradd -m -s /bin/bash wulala

# Set the password for the user 'wulala' to '111'
RUN echo "wulala:111" | chpasswd

# Add the new user to the sudo group
RUN usermod -aG sudo wulala 

# Switch to the new user 'wulala'
USER wulala

# Set the working directory
WORKDIR /home/wulala

# Run any additional commands as 'wulala'
CMD ["/bin/bash"]

