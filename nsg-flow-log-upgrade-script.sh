#!/bin/bash

# Login to Azure (uncomment if not already logged in)
# az login

# Function to pretty print JSON
pretty_print_json() {
    echo "$1" | jq '.'
}

# Get all NSGs
nsgs=$(az network nsg list --query "[].{name:name, resourceGroup:resourceGroup}" -o json)

# Initialize an array to store NSGs with v1 or unspecified flow log version
v1_nsgs=()

# Process each NSG
echo "$nsgs" | jq -c '.[]' | while read -r nsg; do
    name=$(echo $nsg | jq -r '.name')
    rg=$(echo $nsg | jq -r '.resourceGroup')
    
    echo "Checking NSG: $name in Resource Group: $rg"
    
    # Check flow log configuration
    flow_log=$(az network watcher flow-log show --nsg $name -g $rg -o json 2>/dev/null)
    
    if [ -n "$flow_log" ] && [ "$(echo $flow_log | jq -r '.enabled')" == "true" ]; then
        version=$(echo $flow_log | jq -r '.flowAnalyticsConfiguration.networkWatcherFlowAnalyticsConfiguration.version // "unspecified"')
        
        if [ "$version" == "unspecified" ] || [ "$version" == "1" ]; then
            echo "NSG $name has Flow Log v1 or unspecified version. Current configuration:"
            pretty_print_json "$flow_log"
            v1_nsgs+=("$name (Resource Group: $rg)")
        elif [ "$version" == "2" ]; then
            echo "NSG $name has Flow Log v2"
        else
            echo "NSG $name has unknown Flow Log version: $version"
        fi
    else
        echo "Flow log is disabled or not configured for NSG: $name"
    fi
    
    echo "----------------------------------------"
done

# Print summary of NSGs with v1 or unspecified flow log version
echo "Summary of NSGs with Flow Log v1 or unspecified version:"
if [ ${#v1_nsgs[@]} -eq 0 ]; then
    echo "No NSGs found with Flow Log v1 or unspecified version."
else
    for nsg in "${v1_nsgs[@]}"; do
        echo "- $nsg"
    done
fi

echo "Script execution completed."
