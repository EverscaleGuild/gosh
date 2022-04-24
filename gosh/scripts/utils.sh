#	This file is part of Ever OS.
#	
#	Ever OS is free software: you can redistribute it and/or modify 
#	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
#	
#	Copyright 2019-2022 (c) EverX

account_balance() {
    echo $($TONOS_CLI -u $1 account $2 | awk '/balance:/{print sprintf("%.9f", $2/1000000000)}')
}

account_status() {
    echo $($TONOS_CLI -u $1 account $2 | awk '/acc_type:/{print $2}')
}

account_data() {
    echo "$(account_status $1 $2) / $(account_balance $1 $2) EVER"
}