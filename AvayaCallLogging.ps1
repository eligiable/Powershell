#Avaya IP Office SMDR IP Address MUST be set to 0.0.0.0 in IP Office Administrator
[ipaddress]$SMDRHost="172.31.1.8"
[int]$SMDRport=33333

#The location of the log files and name of each log files can be modified below.
$logDir = "D:\Call-Logs"
$CallLog = "calls"
$ErrLog = "error"
$today = Get-Date -format "yyy-MM-d"
Write-Host "Log files initialised"
Write-Host "$logDir\$ErrLog-$today.log"
Write-Host "$logDir\$CallLog-$today.log"

#Change this to false if you only want to log data and not insert into a database
$useDatabase = "true"

#Use the included setup.sql file to import into your MySQL database to setup the required table.
$server = "localhost"
$user = "root"
$password = "Password"
$database = "call_logs"
#DO NOT MODIFY THE FOLLOWING VARIBALE
$connString = "server=" + $server + ";uid=" + $user + ";pwd=" + $password + ";database=" + $database + ";"

#Email configuration parameters
$fromEmail = "alert@example.com"
$toEmail = "it-support@example.com"
$smtpHost = "mail.example.com"
$smtpPort = "587"
$Username = "alert@example.com"
$Password = Get-Content D:\Call-Logs\Script\string.txt | ConvertTo-SecureString
$cred = New-Object -typename System.Management.Automation.PSCredential -argumentlist $Username, $Password

Function NotifyFail([string]$ErrorMessage, [string]$FailedItem, [string]$command) {
    # Email the error and write to the error log
    $today = Get-Date -format "yyy-MM-d"
    $time=Get-Date
    $failMessage = "$time - There was an error on " + $FailedItem + ". The error message was " + $ErrorMessage + ". I couldn't run this command:\n"
    $failMessage += $command."\n" 
    $failMessage | Out-File "$logDir\$ErrLog-$today.log" -Append
    Write-Host $failMessage
    #Write-Host "Send-MailMessage -To $toEmail -From $fromEmail -port $portno -SmtpServer $smtpPort  -Credential $cred -Subject 'SMDR logs failed' -Body $failMessage"
    Send-MailMessage -To $toEmail -From $fromEmail -port $smtpPort -SmtpServer $smtpHost  -Credential $cred -Subject "SMDR logs failed" -Body $failMessage
}

#open connection to Avaya SMDR ports
trap { Write-Error "Could not connect to SMDR host $SMDRHost : $_"; exit } 
$socket = new-object System.Net.Sockets.TcpClient($SMDRHost, $SMDRport)
write-host "Connected to SMDR Host: $SMDRHost on port $SMDRport"
$stream = $socket.GetStream() 
$buffer = new-object System.Byte[] 4096

#Read in data from stream and send to Database
while($true){
    #Sleep for 5 secs to avoid locking up CPU
     Sleep -Milliseconds 5000
    #Update today's date for log files
    $today = Get-Date -format "yyy-MM-d"
    
    #Read from the stream
    $i = $stream.Read($buffer,0,$buffer.Length)
    $EncodedText = New-Object System.Text.ASCIIEncoding
    $data = $EncodedText.GetString($buffer,0, $i)
    
    if($useDatabase.ToLower() -eq "true"){
        $data | foreach {
            $lines = $_.split("`n")
            $lines | foreach {
                $items = $_.split(",")
                if ( $items[0] -ne '') {
                    #write the call data to .\logs\calls-date.log
                    $_ | Out-File "$logDir\$CallLog-$today.log" -Append
    
                    $query =  "INSERT INTO logs ("
                    $query += "CallStart, ConnectedTime, RingTime, Caller, Direction, CalledNumber, DialledNumber, Account, IsInternal, CallID, Continuation, Party1Device, Party1Name, Party2Device, Party2Name, HoldTime, ParkTime, AuthValid, AuthCode, UserCharged, CallCharge, Currency, AmmountAtLastUserCharge, CallUnits, UnitsAtLastUserCharge, CostPerUnit, MarkUp, ExternalTargettingCause, ExternalTargeterID, ExternalTargetedNumber"
                    $query += ") "
                    $query += "VALUES ('" + $items[0] + "','" + $items[1] + "'," + $items[2] + ",'" + $items[3] + "','" + $items[4] + "','" + $items[5] + "','" + $items[6] + "','" + $items[7] + "'," + $items[8] + "," + $items[9] + "," + $items[10]
                    $query += ",'" + $items[11] + "','" + $items[12] + "','" + $items[13] + "','" + $items[14] + "'," + $items[15] + "," + $items[16] + ",'" + $items[17] + "','" + $items[18] + "','" + $items[19] + "','" + $items[20] + "','" + $items[21]
                    $query += "','" + $items[22] + "','" + $items[23] + "','" + $items[24] + "','" + $items[25] + "','" + $items[26] + "','" + $items[27] +"','" + $items[28] +"','" + $items[29] + "')"

                    Write-Host $query
                    #Open Database Connection and email on fail
                    try {
                        Add-Type -Path "C:\Program Files (x86)\MySQL\MySQL Connector Net 6.7.8\Assemblies\v2.0\MySql.Data.dll"
                        $connection = New-Object MySql.Data.MySqlClient.MySqlConnection
                        $connection.ConnectionString = $connString
                        $connection.Open()
                        Write-Host "Open Database Connection"
                    } catch {
                        NotifyFail $_.Exception.Message  $_.Exception.ItemName "Connect to MySQL"
                        Break
                    }#Open DB Connection
                    
                    $command = $connection.CreateCommand()
                    $command.CommandText = $query
                    
                    #Try to insert the record and email on fail
                    $worked = $false
                    while (-not $worked) {
                      try {
                        $RowsReturned = $command.ExecuteNonQuery()
                        $worked = $true  # An exception will skip this
                        Write-Host $RowsReturned "Rows inserted to logs table"
                      } catch {
                        NotifyFail $_.Exception.Message  $_.Exception.ItemName $query
                        Break
                      }#catch
                    }#while not worked
                    
                    #Clean up memory by closing and disposing of the MySQL connection
                    $command.Dispose()
                    $connection.Close()
                    $connection.Dispose()
                    Write-Host "Close Connection"
                } else {
                    Write-Host "No data"
                }#if items[0]
            }#for each lines
        }#for each data
    }#if useDatabase
}#while true
