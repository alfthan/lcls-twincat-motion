bError := TRUE;
nErrorId := nFaultId;
nLatchErrorId := nFaultId;
sErrorMessage := sFaultMessage;

// Raise the fault on the motion stage
stMotionStage.nErrorId := nFaultId;
stMotionStage.sCustomErrorMessage := sFaultMessage;
stMotionStage.bError := TRUE;
