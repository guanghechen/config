# Use the official Ubuntu image as a base
FROM ubuntu:latest

# Update package list and install necessary packages
RUN apt update && apt install -y sudo curl wget

# Create a new user with a password and home directory
RUN useradd -m -s /bin/bash lemon

# Set the password for the user 'lemon' to 'cat'
RUN echo "lemon:cat" | chpasswd

# Add the new user to the sudo group
RUN usermod -aG sudo lemon

# Switch to the new user 'lemon'
USER lemon

# Set the working directory
WORKDIR /home/lemon

# Run any additional commands as 'lemon'
CMD ["/bin/bash"]

