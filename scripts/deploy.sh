#!/bin/bash
source ../.env

# Check if --debug parameter is passed
debug="false"
for arg in "$@"
do
    if [ "$arg" == "--debug" ]
    then
        debug="true"
    fi
done

SIERRA_FILE=../target/dev/migrator_Migrator.sierra.json
SOURCE_ADDRESS=0x5c30f6043246a0c4e45a0316806e053e63746fba3584e1f4fc1d4e7f5300acf
TARGET_ADDRESS=0x007afb15db3fb57839fec89c20754eb59f8d7e3f87d953ee68b0a99b6f527b3e
SLOT=1
VALUE=1000000
OWNER=0x063675fa1ecea10063722e61557ed7f49ed2503d6cdd74f4b31e9770b473650c

# build the solution
build() {
    output=$(scarb build 2>&1)

    if [[ $output == *"Error"* ]]; then
        echo "Error: $output"
        exit 1
    fi
}

# declare the contract
declare() {
    build
    if [[ $debug == "true" ]]; then
        printf "declare %s\n" "$SIERRA_FILE" > debug_migrator.log
    fi
    output=$(starkli declare $SIERRA_FILE --keystore-password $KEYSTORE_PASSWORD --watch 2>&1)

    if [[ $output == *"Error"* ]]; then
        echo "Error: $output"
        exit 1
    fi

    address=$(echo "$output" | grep -oP '0x[0-9a-fA-F]+')
    echo $address
}

# deploy the contract
# $1 - Name
# $2 - Symbol
# $3 - Decimals
# $4 - Owner
deploy() {
    class_hash=$(declare | tail -n 1)
    sleep 1
    
    build
    if [[ $debug == "true" ]]; then
        printf "deploy %s %s %s u256:%s u256:%s %s \n" "$class_hash" "$SOURCE_ADDRESS" "$TARGET_ADDRESS" "$SLOT" "$VALUE" "$OWNER" >> debug_migrator.log
    fi
    output=$(starkli deploy $class_hash "$SOURCE_ADDRESS" "$TARGET_ADDRESS" u256:"$SLOT" u256:"$VALUE" "$OWNER" --keystore-password $KEYSTORE_PASSWORD --watch 2>&1)

    if [[ $output == *"Error"* ]]; then
        echo "Error: $output"
        exit 1
    fi

    address=$(echo "$output" | grep -oP '0x[0-9a-fA-F]+' | tail -n 1) 
    echo $address
}

setup() {
    contract=$(deploy)
    sleep 5
    if [[ $debug == "true" ]]; then
        printf "invoke %s add_minter u256:%s %s \n" "$TARGET_ADDRESS" "$SLOT" "$contract" >> debug_migrator.log
    fi
    output=$(starkli invoke $TARGET_ADDRESS add_minter u256:$SLOT $contract --keystore-password $KEYSTORE_PASSWORD --watch 2>&1)

    if [[ $output == *"Error"* ]]; then
        echo "Error: $output"
        exit 1
    fi

    echo $contract
}

contract_address=$(setup)
echo $contract_address