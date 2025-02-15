#!/bin/bash

CPU_THRESHOLD=80 # Max CPU usage threshold
MEMORY_THRESHOLD=90 # Max memory usage threshold
DISK_THRESHOLD=90 # Max disk usage threshold
NETWORK_THRESHOLD=100000 # Max network usage threshold
LOAD_THRESHOLD=4.0 # Max load average threshold
GPU_THRESHOLD=80 # Max GPU usage threshold
TEMP_THRESHOLD=85  # Example threshold for GPU temperature
LOG_FILE="system_metrics.log" # Log file for system metrics

# Function to check CPU usage
check_cpu() {
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    CPU_OUTPUT="CPU usage: $CPU%"
    if (( $(echo "$CPU > $CPU_THRESHOLD" | bc -l) )); then
        CPU_OUTPUT+="\nALERT: CPU usage is high! Current usage: $CPU%"
    fi
   
}

# Function to check GPU usage and temperature
check_gpu() {
    # Check for NVIDIA GPU
    if command -v nvidia-smi &> /dev/null; then
        GPU_INFO=$(nvidia-smi --query-gpu=gpu_name,utilization.gpu,temperature.gpu --format=csv,noheader,nounits)
        GPU_TYPE=$(echo "$GPU_INFO" | cut -d',' -f1)
        GPU_USAGE=$(echo "$GPU_INFO" | cut -d',' -f2)
        GPU_TEMP=$(echo "$GPU_INFO" | cut -d',' -f3)

    # Check for AMD GPU
    elif command -v radeontop &> /dev/null; then
        GPU_INFO=$(radeontop -d /dev/kfd | grep 'GPU' | awk '{print $3,$4,$5}')
        GPU_TYPE="AMD"
        GPU_USAGE=$(echo "$GPU_INFO" | awk '{print $1}' | sed 's/%//')
        GPU_TEMP=$(echo "$GPU_INFO" | awk '{print $2}' | sed 's/°C//')

    # Check for Intel GPU
    elif command -v intel_gpu_top &> /dev/null; then
        GPU_INFO=$(intel_gpu_top -J | jq '.devices[0] | {name: .name, utilization: .utilization, temperature: .temperature}')
        GPU_TYPE=$(echo "$GPU_INFO" | jq -r '.name')
        GPU_USAGE=$(echo "$GPU_INFO" | jq '.utilization')
        GPU_TEMP=$(echo "$GPU_INFO" | jq '.temperature')

    else
        echo "No compatible GPU found."
        return 1
    fi

    # Prepare output
    GPU_OUTPUT="GPU Type: $GPU_TYPE\nGPU utilization: ${GPU_USAGE}%\nGPU temperature: ${GPU_TEMP}°C"

    # Set alerts for usage and temperature thresholds
    ALERT=""
    
    if (( $(echo "$GPU_USAGE > $GPU_THRESHOLD" | bc -l) )); then
        ALERT+="ALERT: GPU usage exceeded ${GPU_THRESHOLD}%!\n"
    fi
    
    if (( $(echo "$GPU_TEMP > $TEMP_THRESHOLD" | bc -l) )); then
        ALERT+="ALERT: GPU temperature exceeded ${TEMP_THRESHOLD}°C!\n"
    fi

    # Append alerts to output if any
    if [ -n "$ALERT" ]; then
        GPU_OUTPUT+="$ALERT"
    fi

    echo -e "$GPU_OUTPUT"
} 
# Function to check Memory usage
check_memory() {
    TOTAL_MEMORY_GB=$(free -g | awk '/Mem/{print $2}')
    USED_MEMORY_GB=$(free -g | awk '/Mem/{print $3}')
    MEMORY_PERCENTAGE=$(free | awk '/Mem/{printf("%.2f", $3/$2*100)}')
    MEMORY_OUTPUT="Total Memory: ${TOTAL_MEMORY_GB} GB\nUsed Memory: ${USED_MEMORY_GB} GB\nMemory usage: $USED_MEMORY_GB / $TOTAL_MEMORY_GB * 100 = $MEMORY_PERCENTAGE%"
    if (( $(echo "$MEMORY_PERCENTAGE > $MEMORY_THRESHOLD" | bc -l) )); then
        MEMORY_OUTPUT+="\nALERT: Memory usage is high! Current usage: ${MEMORY_PERCENTAGE}%"
    fi
    echo -e "$MEMORY_OUTPUT"
}

# Function to check Disk usage
check_disk() {
    DISK=$(df / | grep / | awk '{ print $5 }' )
    DISK_OUTPUT="Disk usage: $DISK"
    if (( DISK > DISK_THRESHOLD )); then
        DISK_OUTPUT+="\nALERT: Disk usage is high! Current usage: $DISK%"
    fi
    echo -e "$DISK_OUTPUT"
}

# Function to check Disk health
check_disk_health() {
    DISK_HEALTH=$(smartctl -H /dev/sda | grep "SMART Health Status" | awk '{print $4}')
    DISK_HEALTH_OUTPUT="Disk health status: $DISK_HEALTH"
    if [ "$DISK_HEALTH" != "OK" ]; then
        DISK_HEALTH_OUTPUT+="\nALERT:faild"
    fi
    echo -e "$DISK_HEALTH_OUTPUT"
}

# Function to check Network usage
check_network() {
 # Read RX and TX bytes for eth0
    ETH_RX=$(cat /sys/class/net/eth0/statistics/rx_bytes)
    ETH_TX=$(cat /sys/class/net/eth0/statistics/tx_bytes)

    # Initialize NETWORK_OUTPUT variable
    NETWORK_OUTPUT=""

    # Check if RX or TX bytes exceed the threshold
    if (( ETH_RX > NETWORK_THRESHOLD || ETH_TX > NETWORK_THRESHOLD )); then
        NETWORK_OUTPUT+="\nAlert: Network eth0 usage is high!\n"
    fi

    # Append eth0 statistics to output
    NETWORK_OUTPUT+="eth0 RX bytes: $ETH_RX\neth0 TX bytes: $ETH_TX"

    # Read RX and TX bytes for lo (loopback interface)
    LO_RX=$(cat /sys/class/net/lo/statistics/rx_bytes)
    LO_TX=$(cat /sys/class/net/lo/statistics/tx_bytes)
     if (( LO_RX > NETWORK_THRESHOLD || LO_TX > NETWORK_THRESHOLD )); then
        NETWORK_OUTPUT+="\nAlert: Network of l0 usage is high!\n"
    fi
    # Append lo statistics to output
    NETWORK_OUTPUT+="\nlo RX bytes: $LO_RX\nlo TX bytes: $LO_TX"

    # Print the final output
    echo -e "$NETWORK_OUTPUT"
}


# Function to check system load
check_load() {
 LOAD_1_MIN=$(uptime | awk -F 'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    LOAD_5_MIN=$(uptime | awk -F 'load average:' '{print $2}' | awk '{print $2}' | sed 's/,//')
    LOAD_15_MIN=$(uptime | awk -F 'load average:' '{print $2}' | awk '{print $3}' | sed 's/,//')

    # Get the number of CPU cores and active processes
    CPU_CORES=$(nproc)
    ACTIVE_PROCESSES=$(ps -e | wc -l)

    # Display system load metrics
    LOAD_OUTPUT="System Load Metrics:\n"
    LOAD_OUTPUT+=" 1-minute Load Average: $LOAD_1_MIN\n"
    LOAD_OUTPUT+=" 5-minute Load Average: $LOAD_5_MIN\n"
    LOAD_OUTPUT+=" 15-minute Load Average: $LOAD_15_MIN\n"
    LOAD_OUTPUT+=" Number of CPU Cores: $CPU_CORES\n"
    LOAD_OUTPUT+=" Total Active Processes: $ACTIVE_PROCESSES"
 if (( $(echo "$LOAD_1_MIN > $LOAD_THRESHOLD" | bc -l) )) || \
   (( $(echo "$LOAD_5_MIN > $LOAD_THRESHOLD" | bc -l) )) || \
   (( $(echo "$LOAD_15_MIN > $LOAD_THRESHOLD" | bc -l) )); then
    LOAD_OUTPUT+="\nALERT: High system load detected!"
fi

    echo -e "$LOAD_OUTPUT"
}

# Main function to display metrics in Zenity dialog with buttons.
monitor_system() {
   while true; do 
       OUTPUT=$(zenity --list --title="System Monitoring" --column="Metrics" \
           "CPU Usage" \
           "GPU Usage" \
           "Memory Usage" \
           "Disk Usage" \
           "Disk Health" \
           "Network Usage" \
           "Load Average")
       
       case "$OUTPUT" in
           "CPU Usage")
               METRIC_OUTPUT="$(check_cpu)" ;;
           "GPU Usage")
               METRIC_OUTPUT="$(check_gpu)" ;;
           "Memory Usage")
               METRIC_OUTPUT="$(check_memory)" ;;
           "Disk Usage")
               METRIC_OUTPUT="$(check_disk)" ;;
           "Disk Health")
               METRIC_OUTPUT="$(check_disk_health)" ;;
           "Network Usage")
               METRIC_OUTPUT="$(check_network)" ;;
           "Load Average")
               METRIC_OUTPUT="$(check_load)" ;;
       esac

       # Log output and display it in Zenity dialog.
       echo "$(date): ${METRIC_OUTPUT}" | tee -a "$LOG_FILE" | zenity --info --text="$METRIC_OUTPUT" --width=400 --height=300

       sleep 5 # Wait for 5 seconds before the next iteration. 
   done 
}

# Start the monitoring process.
monitor_system 

zenity --info --icon="C:\Users\20101\Desktop\os project\4617522.png"