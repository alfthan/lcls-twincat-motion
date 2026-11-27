rtExec(CLK:=bExecute);

// Start of a new attempt: clear the latched state, deactivate the drive, and
// make sure we are not holding on to a stale set position command.
IF rtExec.Q THEN
    stMotionStage.bReset := TRUE;
    stMotionStage.bEnable := FALSE;
    stMotionStage.nEnableMode := E_StageEnableMode.NEVER;
    stMotionStage.sCustomErrorMessage := '';
    stSetPositionOptions.ClearPositionLag := TRUE;
    bSetPosExec := FALSE;
    bSetPosDoneLatch := FALSE;
    bSetPosFailed := FALSE;
    nLatchErrorId := 0;
    bResetDone := FALSE;
    bSetDone := FALSE;
    bError := FALSE;
    nErrorId := 0;
    sErrorMessage := '';
END_IF

// Latch mcSetPos failures: the Error output can fall again before we look at it.
rtSetPosError(CLK:=mcSetPos.Error);
IF rtSetPosError.Q THEN
    bSetPosFailed := TRUE;
    nLatchErrorId := mcSetPos.ErrorID;
END_IF

bResetDone := NOT stMotionStage.bError AND NOT stMotionStage.bBusy;

IF bResetDone THEN
    stMotionStage.bReset := FALSE;
END_IF

// The wait for the set position to complete is bounded: if the axis readback
// never matches fStartPosition we fault instead of waiting forever.
tonTimeout(
    IN:=bExecute AND bResetDone AND NOT bSetDone AND NOT bError,
    PT:=tTimeout,
    ET=>tElapsed
);

IF bExecute AND bResetDone AND NOT bSetDone AND NOT bError THEN
    // The position can only be set with the drive deactivated.
    stMotionStage.bEnable := FALSE;
    IF stMotionStage.Axis.NcToPlc.ActPos = fStartPosition THEN
        // The axis readback already matches the requested position.
        bSetDone := TRUE;
        bSetPosExec := FALSE;
    ELSIF tonTimeout.Q THEN
        // The wait expired: count the attempt as failed, raise a fault with an
        // explicit message, and clear the command so we stop retrying.
        RaiseFault(
            nFaultId:=E_LCLSMotionError.TIMEOUT,
            sFaultMessage:=CONCAT('Timed out setting position to ', LREAL_TO_STRING(fStartPosition))
        );
        bSetPosExec := FALSE;
    ELSIF bSetPosFailed THEN
        // MC_SetPosition reported a failure: raise a fault with the command's own
        // error code and an explicit message, and clear the command.
        RaiseFault(
            nFaultId:=nLatchErrorId,
            sFaultMessage:=CONCAT('MC_SetPosition failed setting position to ', LREAL_TO_STRING(fStartPosition))
        );
        bSetPosExec := FALSE;
    ELSE
        // Command the set position, and stop re-commanding once the NC reports
        // done; the matching readback is still bounded by tTimeout.
        bSetPosExec := NOT bSetPosDoneLatch;
    END_IF
ELSE
    // Idle, done, or faulted: never leave a stale command behind.
    bSetPosExec := FALSE;
END_IF

mcSetPos(
    Axis:=stMotionStage.Axis,
    Execute:=bSetPosExec,
    Position:=fStartPosition,
    Mode:=FALSE,
    Options:=stSetPositionOptions,
    Done=>bSetPosDone
);

IF bSetPosDone THEN
    bSetPosDoneLatch := TRUE;
END_IF
