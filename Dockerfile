# Use the official Ubuntu 22.04 base image
FROM ubuntu:22.04
# Install necessary packages including Zenity
RUN apt-get update && apt-get install -y \
    zenity \
    smartmontools \
    x11-apps \
    xauth \
    xserver-xorg-video-dummy \
    && rm -rf /var/lib/apt/lists/*
# Set the working directory inside the container
WORKDIR /project
# Copy all files from the "os prOject" folder into the container's working directory
COPY  . .
# Make the bash script executable
RUN chmod +x finalmonitor.sh
# Set environment variable
ENV PORT=5000
# Expose port for external access
EXPOSE 5000
# Default command to execute your script
CMD ["bash", "finalmonitor.sh"]

