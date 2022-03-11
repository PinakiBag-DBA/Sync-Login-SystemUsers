# ChildScript to execute the exact statement in the secondary node
# This takes the followings as the inputs 
#	the secondary node name
#	the query to execute
#	the database name on which the query to execute
# This returns Success or the Error Message as the output

$UserAction = $args[0] 				# Input parameter: SQL Query to execute
$SystemDatabaseName = $args[1] 		# Input parameter: Database Name
$SecondaryInstanceName = $args[2] 	# Input parameter: Secondary Instance Name

$ExecutionOutput = 'Success'

try{
Invoke-Sqlcmd -ServerInstance $SecondaryInstanceName -Database $SystemDatabaseName -Query $UserAction -ErrorAction 'Stop'
}
catch{
$ExecutionOutput = $_
}

# Send the Execution message to the MainScript
return $ExecutionOutput
