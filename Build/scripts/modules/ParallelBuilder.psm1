#requires -Version 5.1
Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Provides parallel build orchestration capabilities for independent build tasks.

.DESCRIPTION
    This module manages parallel execution of build jobs using PowerShell background jobs
    with intelligent CPU-aware throttling to maximize throughput without overwhelming the system.
#>

function Get-OptimalParallelJobCount {
    <#
    .SYNOPSIS
        Calculates the optimal number of parallel jobs based on CPU count.
    
    .PARAMETER MaxJobs
        Optional maximum job count override. If not specified, uses CPU-based calculation.
    
    .PARAMETER ReserveCores
        Number of CPU cores to reserve for system use. Defaults to 1.
    #>
    [CmdletBinding()]
    param(
        [int]$MaxJobs = 0,
        [int]$ReserveCores = 1
    )

    if ($MaxJobs -gt 0) {
        return $MaxJobs
    }

    # Get logical processor count
    $cpuCount = [Environment]::ProcessorCount
    
    # Reserve at least one core for system responsiveness, but use all available cores
    # for maximum build throughput on build machines
    $optimalJobs = [Math]::Max(1, $cpuCount - $ReserveCores)
    
    # Only log if Write-BuildLog is available
    if (Get-Command Write-BuildLog -ErrorAction SilentlyContinue) {
        Write-BuildLog -Message "Detected $cpuCount logical processors, using $optimalJobs parallel jobs" -Level 'DEBUG'
    }
    
    return $optimalJobs
}

function Start-ParallelBuildJobs {
    <#
    .SYNOPSIS
        Executes build tasks in parallel with intelligent throttling.
    
    .PARAMETER BuildTasks
        Array of scriptblocks to execute in parallel. Each scriptblock represents one build task.
    
    .PARAMETER TaskDescriptions
        Array of description strings corresponding to each build task for logging.
    
    .PARAMETER TaskArguments
        Array of argument arrays to pass to each task scriptblock.
    
    .PARAMETER MaxParallelJobs
        Maximum number of jobs to run concurrently. If 0 or not specified, auto-detects based on CPU count.
    
    .PARAMETER InitializationScript
        Optional scriptblock to run in each job before executing the build task (e.g., import modules).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock[]]$BuildTasks,
        
        [Parameter(Mandatory)]
        [string[]]$TaskDescriptions,
        
        [object[][]]$TaskArguments = @(),
        
        [int]$MaxParallelJobs = 0,
        
        [scriptblock]$InitializationScript
    )

    if ($BuildTasks.Count -eq 0) {
        if (Get-Command Write-BuildLog -ErrorAction SilentlyContinue) {
            Write-BuildLog -Message 'No build tasks to execute.' -Level 'DEBUG'
        }
        return
    }

    if ($BuildTasks.Count -ne $TaskDescriptions.Count) {
        throw 'BuildTasks and TaskDescriptions arrays must have the same length.'
    }

    # Ensure TaskArguments is properly sized
    if ($TaskArguments.Count -eq 0) {
        $TaskArguments = @(,@()) * $BuildTasks.Count
    }
    elseif ($TaskArguments.Count -ne $BuildTasks.Count) {
        throw 'TaskArguments array must have the same length as BuildTasks or be empty.'
    }

    $maxJobs = Get-OptimalParallelJobCount -MaxJobs $MaxParallelJobs
    
    # If only one job or max parallelism is 1, execute sequentially
    if ($BuildTasks.Count -eq 1 -or $maxJobs -eq 1) {
        if (Get-Command Write-BuildLog -ErrorAction SilentlyContinue) {
            Write-BuildLog -Message 'Executing build tasks sequentially (count=1 or max=1)' -Level 'DEBUG'
        }
        for ($i = 0; $i -lt $BuildTasks.Count; $i++) {
            if (Get-Command Write-BuildLog -ErrorAction SilentlyContinue) {
                Write-BuildLog -Message "Executing: $($TaskDescriptions[$i])" -Level 'INFO'
            }
            & $BuildTasks[$i] @($TaskArguments[$i])
        }
        return
    }

    if (Get-Command Write-BuildLog -ErrorAction SilentlyContinue) {
        Write-BuildLog -Message "Starting parallel build execution: $($BuildTasks.Count) tasks, max $maxJobs concurrent jobs" -Level 'INFO'
    }

    $jobs = @()
    $taskIndex = 0
    $completedCount = 0
    $failedJobs = @()

    try {
        while ($taskIndex -lt $BuildTasks.Count -or $jobs.Count -gt 0) {
            # Start new jobs up to the throttle limit
            while ($taskIndex -lt $BuildTasks.Count -and $jobs.Count -lt $maxJobs) {
                $task = $BuildTasks[$taskIndex]
                $description = $TaskDescriptions[$taskIndex]
                $args = $TaskArguments[$taskIndex]
                
                if (Get-Command Write-BuildLog -ErrorAction SilentlyContinue) {
                    Write-BuildLog -Message "[Parallel] Starting: $description" -Level 'INFO'
                }
                
                # Execute the task scriptblock with its arguments directly
                $job = Start-Job -ScriptBlock $task -ArgumentList $args
                
                # Attach metadata to the job for tracking
                $job | Add-Member -NotePropertyName 'TaskDescription' -NotePropertyValue $description -Force
                $job | Add-Member -NotePropertyName 'TaskIndex' -NotePropertyValue $taskIndex -Force
                
                $jobs += $job
                $taskIndex++
            }

            # Wait for any job to complete
            if ($jobs.Count -gt 0) {
                $completed = $jobs | Wait-Job -Any -Timeout 1
                
                if ($completed) {
                    foreach ($job in @($completed)) {
                        $description = $job.TaskDescription
                        
                        # Check job state and capture output
                        $output = Receive-Job -Job $job -ErrorAction SilentlyContinue -ErrorVariable jobErrors -WarningAction SilentlyContinue
                        
                        # A job is only considered failed if it's in the Failed state
                        # Having errors in the error stream doesn't necessarily mean failure,
                        # as the script may handle exceptions internally
                        if ($job.State -eq 'Failed') {
                            if (Get-Command Write-BuildLog -ErrorAction SilentlyContinue) {
                                Write-BuildLog -Message "[Parallel] FAILED: $description" -Level 'ERROR'
                            }
                            
                            # Capture error details
                            $errorDetails = if ($jobErrors.Count -gt 0) {
                                $jobErrors | ForEach-Object { $_.ToString() } | Out-String
                            } else {
                                'Job failed with no specific error message.'
                            }
                            
                            # Also capture any output for debugging
                            if ($output) {
                                $errorDetails += "`n`nJob Output:`n$output"
                            }
                            
                            $failedJobs += [PSCustomObject]@{
                                Description = $description
                                TaskIndex = $job.TaskIndex
                                Error = $errorDetails
                                Output = $output
                            }
                        }
                        else {
                            if (Get-Command Write-BuildLog -ErrorAction SilentlyContinue) {
                                Write-BuildLog -Message "[Parallel] Completed: $description" -Level 'SUCCESS'
                            }
                            $completedCount++
                            
                            # Log errors that occurred but didn't cause job failure (for diagnostics)
                            if ($jobErrors.Count -gt 0 -and (Get-Command Write-BuildLog -ErrorAction SilentlyContinue)) {
                                $errorSummary = $jobErrors | ForEach-Object { $_.ToString() } | Out-String
                                Write-BuildLog -Message "[Parallel] Note: $description completed successfully despite having errors in the stream:`n$errorSummary" -Level 'DEBUG'
                            }
                            
                            # Log output if present
                            if ($output -and (Get-Command Write-BuildLog -ErrorAction SilentlyContinue)) {
                                Write-BuildLog -Message "[Parallel] Output from ${description}:`n$output" -Level 'DEBUG'
                            }
                        }
                        
                        # Remove from active jobs list
                        $jobs = @($jobs | Where-Object { $_.Id -ne $job.Id })
                        
                        # Clean up the job
                        Remove-Job -Job $job -Force
                    }
                }
            }
        }

        # Report final status
        if ($failedJobs.Count -gt 0) {
            if (Get-Command Write-BuildLog -ErrorAction SilentlyContinue) {
                Write-BuildLog -Message "Parallel build completed with errors: $completedCount succeeded, $($failedJobs.Count) failed" -Level 'ERROR'
                
                # Report all failures
                foreach ($failure in $failedJobs) {
                    Write-BuildLog -Message "Failed task: $($failure.Description)" -Level 'ERROR'
                    Write-BuildLog -Message "Error details: $($failure.Error)" -Level 'ERROR'
                }
            }
            
            throw "Parallel build failed: $($failedJobs.Count) task(s) failed. See log for details."
        }
        else {
            if (Get-Command Write-BuildLog -ErrorAction SilentlyContinue) {
                Write-BuildLog -Message "Parallel build completed successfully: $completedCount tasks" -Level 'SUCCESS'
            }
        }
    }
    finally {
        # Ensure all jobs are cleaned up
        if ($jobs.Count -gt 0) {
            if (Get-Command Write-BuildLog -ErrorAction SilentlyContinue) {
                Write-BuildLog -Message 'Cleaning up remaining background jobs...' -Level 'DEBUG'
            }
            $jobs | Stop-Job -ErrorAction SilentlyContinue
            $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-BuildTasksInParallel {
    <#
    .SYNOPSIS
        Simplified wrapper for executing build tasks in parallel with module imports.
    
    .PARAMETER Tasks
        Array of hashtables, each containing 'Script' (scriptblock), 'Description' (string),
        and optionally 'Arguments' (array of arguments to pass to the script).
    
    .PARAMETER MaxParallelJobs
        Maximum number of concurrent jobs. Auto-detects if not specified.
    
    .PARAMETER ModulesToImport
        Array of module paths to import in each job before execution.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable[]]$Tasks,
        
        [int]$MaxParallelJobs = 0,
        
        [string[]]$ModulesToImport = @()
    )

    if ($Tasks.Count -eq 0) {
        return
    }

    $scripts = @()
    $descriptions = @()
    $arguments = @()
    
    foreach ($task in $Tasks) {
        if (-not $task.ContainsKey('Script') -or -not $task.ContainsKey('Description')) {
            throw 'Each task must contain both Script and Description properties.'
        }
        
        $scripts += $task.Script
        $descriptions += $task.Description
        
        # Get arguments if provided
        if ($task.ContainsKey('Arguments')) {
            $arguments += ,@($task.Arguments)
        }
        else {
            $arguments += ,@()
        }
    }

    $initScript = $null
    if ($ModulesToImport.Count -gt 0) {
        $initScript = {
            param($Modules)
            foreach ($module in $Modules) {
                Import-Module $module -Force -ErrorAction Stop
            }
        }.GetNewClosure()
        
        # Bind the module list to the scriptblock
        $initScript = [scriptblock]::Create(
            "`$Modules = @('$($ModulesToImport -join "','")'); " + $initScript.ToString()
        )
    }

    Start-ParallelBuildJobs -BuildTasks $scripts -TaskDescriptions $descriptions `
        -TaskArguments $arguments -MaxParallelJobs $MaxParallelJobs -InitializationScript $initScript
}

Export-ModuleMember -Function Get-OptimalParallelJobCount, Start-ParallelBuildJobs, Invoke-BuildTasksInParallel
