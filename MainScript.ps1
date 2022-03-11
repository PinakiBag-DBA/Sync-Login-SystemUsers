# MainScript to process the Synch operation
# This takes the listener name as the input

$ListenerName = $args[0] 		# Input parameter: Listener name

# Functions

# Gather the information from the table within MckServiceManagement to be processed
# All the records which are new or errored out in previous execution
function FetchInfoToProcess{
	param([string] $Instance)
	try{
	$SqlQueryFetchInfoToProcess = "SELECT [SequenceNumber]
									  ,[LoginName]
									  ,convert(varchar(1000),[LoginSID],2) as [LoginSID]
									  ,[UserName]
									  ,[ActionCode]
									  ,[SystemDatabaseName]
									  ,[ActionNode]
									  ,[SecondoryNode]
									  ,[ProcessedFlag]
									  ,[UserAction]
									  ,[ProcessedMessage]
									  ,Convert(varchar(25),[ActionDateTime],121) AS [ActionDateTime]
									  ,[ErrorCounter]
								  FROM [synch].[LoginSysUsersInfo]
									WHERE [ProcessedFlag] = 'N' or [ProcessedFlag] = 'E'
									ORDER BY SequenceNumber"
    $OutputFetchInfoToProcess = Invoke-Sqlcmd -ServerInstance $Instance -Database "MckServiceManagement" -Query $SqlQueryFetchInfoToProcess -ErrorAction Stop
	}catch{
		throw
	}
    return $OutputFetchInfoToProcess
}

# Update the table in MckServiceManagement database in case of success or failure
function UpdateRecord{
	param([string] $Instance,[string] $SQLQuery)
	try{
    Invoke-Sqlcmd -ServerInstance $Instance -Database "MckServiceManagement" -Query $SQLQuery -ErrorAction Stop
	}catch{
		throw
	}
}

# Prepare and execute the query once the processing is failed
function ProcessFailedCondition{
	param([string] $Instance,[string] $ErrorMessage,[int] $ErrorCounter,[string] $WhereClause)
	try{
	
	$SQLQueryUpdate = "SET QUOTED_IDENTIFIER OFF
	GO

	UPDATE [synch].[LoginSysUsersInfo]
	   SET [ProcessedFlag] = 'E'
		  ,[ProcessedMessage] = ""$ErrorMessage""
		  ,[ErrorCounter] = $ErrorCounter
		  " + $WhereClause
							  
	UpdateRecord $Instance $SQLQueryUpdate
	}catch{
		throw
	}
}

# Prepare and execute the query once the processing is successful
function ProcessSuccessCondition{
	param([string] $Instance,[string] $WhereClause)
	try{
	$SQLQueryUpdate = "SET QUOTED_IDENTIFIER OFF
	GO
	
	UPDATE [synch].[LoginSysUsersInfo]
	   SET [ProcessedFlag] = 'S'
		  ,[ProcessedMessage] = 'Successful'
		  ,[ErrorCounter] = 0
		" + $WhereClause
	  
	UpdateRecord $Instance $SQLQueryUpdate
	}catch{
		throw
	}
}

# End of Functions

# Main Processing
$ErrorMessages = "" 		# To prepare the report of the failed conditions
try{
$RecordsToProcess = FetchInfoToProcess $ListenerName 
if ($RecordsToProcess.Count -ne 0)
{
	# Store the records in a temporaray table
	$Records = @()
	foreach ($Record in $RecordsToProcess)
	{
		$Single = new-object PSObject
		$Single | Add-Member -MemberType NoteProperty -Name "SequenceNumber" -Value $Record.SequenceNumber
		$Single | Add-Member -MemberType NoteProperty -Name "LoginName" -Value $Record.LoginName
		$Single | Add-Member -MemberType NoteProperty -Name "LoginSID" -Value $Record.LoginSID
		$Single | Add-Member -MemberType NoteProperty -Name "UserName" -Value $Record.UserName
		$Single | Add-Member -MemberType NoteProperty -Name "ActionCode" -Value $Record.ActionCode
		$Single | Add-Member -MemberType NoteProperty -Name "SystemDatabaseName" -Value $Record.SystemDatabaseName
		$Single | Add-Member -MemberType NoteProperty -Name "UserAction" -Value $Record.UserAction
		$Single | Add-Member -MemberType NoteProperty -Name "ActionDateTime" -Value $Record.ActionDateTime
		$Single | Add-Member -MemberType NoteProperty -Name "ActionNode" -Value $Record.ActionNode
		$Single | Add-Member -MemberType NoteProperty -Name "SecondaryNode" -Value $Record.SecondoryNode
		$Single | Add-Member -MemberType NoteProperty -Name "ProcessedFlag" -Value $Record.ProcessedFlag
		$Single | Add-Member -MemberType NoteProperty -Name "ProcessedMessage" -Value $Record.ProcessedMessage
		$Single | Add-Member -MemberType NoteProperty -Name "ErrorCounter" -Value $Record.ErrorCounter
		
		$Records += $Single		
	}
	$FailedLogins = @()			# for storing the sids and the secondary node information of the errored scenarios
	
	# Process the records one-by-one
	foreach ($EachRecord in $Records)
	{
		# Store the values in the variables for further processing
		$SequenceNumber = $EachRecord.SequenceNumber
		$LoginName = $EachRecord.LoginName
        $LoginSID = $EachRecord.LoginSID
        $UserName = $EachRecord.UserName		
		$ActionCode = $EachRecord.ActionCode
        $SystemDatabaseName = $EachRecord.SystemDatabaseName
		$ActionNode = $EachRecord.ActionNode
		$SecondaryNode = $EachRecord.SecondaryNode
        $ProcessedFlag = $EachRecord.ProcessedFlag
		$UserAction = $EachRecord.UserAction
        $ProcessedMessage = $EachRecord.ProcessedMessage
        $ActionDateTime = $EachRecord.ActionDateTime
		$ErrorCounter = $EachRecord.ErrorCounter
		
		#Prepare WHERE clause
		$WhereClause = "WHERE [SequenceNumber] = $SequenceNumber
				          AND [LoginName] = '$LoginName'
				          AND [LoginSID] = 0x$LoginSID
				          AND [ActionCode] = '$ActionCode'
				          AND [ActionNode] = '$ActionNode'
				          AND [SecondoryNode] = '$SecondaryNode'
                          AND [ProcessedFlag] = '$ProcessedFlag'
                          AND [UserAction] = ""$UserAction""
                          AND [ActionDateTime] = '$ActionDateTime'
                          "

        if ($UserName -ne [System.DBNull]::Value)
        {
            $WhereClause += "AND [UserName] = '$UserName'
            "
        }
        else
        {
            $WhereClause += "AND [UserName] IS NULL
            "   
        }
        if ($SystemDatabaseName -ne [System.DBNull]::Value)
        {
            $WhereClause += "AND [SystemDatabaseName] = '$SystemDatabaseName'
            "
        }
        else
        {
            $WhereClause += "AND [SystemDatabaseName] IS NULL
            "   
        }
		if ($ProcessedMessage -ne [System.DBNull]::Value)
        {
            $WhereClause += "AND [ProcessedMessage] = ""$ProcessedMessage""
            "
        }
        else
        {
            $WhereClause += "AND [ProcessedMessage] IS NULL
            "   
        }
        if ($ErrorCounter -ne [System.DBNull]::Value)
        {
            $WhereClause += "AND [ErrorCounter] = $ErrorCounter
            "
        }
        else
        {
            $WhereClause += "AND [ErrorCounter] IS NULL
            "   
        }
		# End of WHERE clause preperation
		
		if ($FailedLogins.count -ne 0)			# One or more records are already failed in this execution, need to compare with the current record
		{
            $FurtherProcessingRequired = $true
			foreach($FailedOne in $FailedLogins)
			{
				$FailedOneSID = $FailedOne.LoginSID
				$FailedOneSec = $FailedOne.SecondaryNode
				if (($FailedOneSID -eq $LoginSID) -and ($FailedOneSec -eq $SecondaryNode)) 		# The login sid and secondary node is matching, Skip the processing
				{
					$ErrorMessage = "Skipped as the previous operation was failed"
                    if ($ErrorCounter -eq [System.DBNull]::Value)
	                {
		                $ErrorCounter = 1
	                }
	                else
	                {
		                $ErrorCounter += 1
	                }	
					
					ProcessFailedCondition $ListenerName $ErrorMessage $ErrorCounter $WhereClause					
					$ErrorMessages += "Error occur while processing the statement ""$UserAction"" for the login $LoginName (0x$LoginSID) on the instance $SecondaryNode with the message: "+$ErrorMessage+"`r`n"	
					
                    $FurtherProcessingRequired = $false
					break
				}				
			}
            if ($FurtherProcessingRequired)						# The login sid and secondary node is not matching
            {
                # Set the database name
				$ModifiedSysDBName = "master"		        
		        if ($EachRecord.SystemDatabaseName -ne [System.DBNull]::Value)
		        {
			        $ModifiedSysDBName = $EachRecord.SystemDatabaseName
		        }
				
				# Execute the Child Script to execute the statement in the secondary node
		        $ScriptToRun = $PSScriptRoot + "\ChildScript.ps1" 		
		        $ChildOutput = &$ScriptToRun $UserAction $ModifiedSysDBName $SecondaryNode	
        
                if ($ChildOutput -eq 'Success')							# Success Condition
                {			
				    ProcessSuccessCondition $ListenerName $WhereClause
                }
		        else													# Failure Condition
		        {
					# Add the failed login sid and secondary node to the list   		
			        $SingleLogin = new-object PSObject
			        $SingleLogin | Add-Member -MemberType NoteProperty -Name "LoginSID" -Value $LoginSID
			        $SingleLogin | Add-Member -MemberType NoteProperty -Name "SecondaryNode" -Value $SecondaryNode
			
			        $FailedLogins += $SingleLogin
					
					$ErrorMessage = $ChildOutput				
				    ProcessFailedCondition $ListenerName $ErrorMessage $ErrorCounter $WhereClause					
				    $ErrorMessages += "Error occur while processing the statement ""$UserAction"" for the login $LoginName (0x$LoginSID) on the instance $SecondaryNode with the message: "+$ErrorMessage+"`r`n"				    
		        }
            }			 			
		}
		else									# No records are failed so far in this execution 
        {
			# Set the database name
            $ModifiedSysDBName = "master"		    
		    if ($EachRecord.SystemDatabaseName -ne [System.DBNull]::Value)
		    {
			    $ModifiedSysDBName = $EachRecord.SystemDatabaseName
		    }			
			
			# Execute the Child Script to execute the statement in the secondary node
		    $ScriptToRun = $PSScriptRoot + "\ChildScript.ps1" 		
		    $ChildOutput = &$ScriptToRun $UserAction $ModifiedSysDBName $SecondaryNode	
        
            if ($ChildOutput -eq 'Success')							# Success Condition
            {			
				ProcessSuccessCondition $ListenerName $WhereClause
            }
		    else													# Failure Condition
		    {
			    if ($ErrorCounter -eq [System.DBNull]::Value)
	            {
		            $ErrorCounter = 1
	            }
	            else
	            {
		            $ErrorCounter += 1
	            }	
				
				# Add the failed login sid and secondary node to the list
			    $SingleLogin = new-object PSObject
			    $SingleLogin | Add-Member -MemberType NoteProperty -Name "LoginSID" -Value $LoginSID
			    $SingleLogin | Add-Member -MemberType NoteProperty -Name "SecondaryNode" -Value $SecondaryNode
			
			    $FailedLogins += $SingleLogin
				
				$ErrorMessage = $ChildOutput				
				ProcessFailedCondition $ListenerName $ErrorMessage $ErrorCounter $WhereClause					
				$ErrorMessages += "Error occur while processing the statement ""$UserAction"" for the login $LoginName (0x$LoginSID) on the instance $SecondaryNode with the message: "+$ErrorMessage+"`r`n"				    
		    }   
        }		
	}
}
}catch{
	$ErrorCode = $_
	$ErrorMessages += "Error occur while processing with the message: " + $ErrorCode +"`r`n"
}

# Generate Error Report
$ErrorMessages += "Report Generated on " + (Get-Date).ToString()

$FileErrorMessage = $PSScriptRoot + "\Reports\ErrorReport_" + $(Get-Date -UFormat "%Y-%m-%d_%H-%m-%S") +".txt" 
$ErrorMessages | Out-File -FilePath $FileErrorMessage

# End of Main Processing