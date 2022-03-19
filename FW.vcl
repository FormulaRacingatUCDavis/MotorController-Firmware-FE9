; PARAMETER_ENTRY "Program"
;		TYPE		PROGRAM
;		Level		0
;	END
; PARAMETER_ENTRY "UCDFRStateData"
;		TYPE		Monitor
;		Level		1
;	END
; parameter_entry "State"
; 	type Monitor
; 	width 16bit
; 	address user4
; 	units @
; end
; parameter_entry "SetInterlock"
; 	type Monitor
; 	width 16bit
; 	address User_bit4
; 	units @
; end

; Formula Racing UCD
; Curtis 1239E Motor Controller Code
; Zhening (Sirius) Zhang
; Edited by FRUCD

VCL_App_Ver = 100 	;Set VCL software revision

;--------------------
; I/O Requirements
;--------------------
;	For functions to work properly:
;       Used CAN message for controll
;
;		Drive1 connected to PWM1
;		Drive2 connected to PWM2
;		Drive3 connected to PWM3

Drive1			equals	PWM1
Drive2			equals	PWM2
Drive3			equals	PWM3
Drive4          equals  PWM4

HVRequest		equals	User_bit1
DriveRequest	equals	User_bit2
NEUTRAL			equals	User_bit3

; CAN variables
PDO1			equals	User1  
PDO2			equals	User2
PDO3			equals	User3
; State machine
State			equals	User4

temp            equals	User9

throttle_high	equals	User10
throttle_low	equals	User11

Count_Low		equals	User12
Count_High		equals  User13

BMS_temp		equals	User14
SOC 			equals  User15
flashing_H		equals	User16
flashing_L		equals	User17
SetInterlock	equals	User_bit4

e_stop          equals  User18
e_stop_check    equals  User19

;---------------- Initialization ----------------------------

SetInterlock = 0
VCL_Throttle = 0
VCL_Brake = 0
state = 0
DisplayState = 1
Count_Low = 0
Count_High = 0
flashing_L = 0
flashing_H = 0
e_stop = 0
e_stop_check = 0

;---------------- CAN Variables -----------------------------
pdoSend equals can1
pdoRecv equals can2
debug   equals can3
pdoAck	equals can4
eStop   equals can5

;FE_Main_State	equals Main_State
;FE_Cap_Vol		equals Capacitor_Voltage
;FE_Mapped_Throttle	equals ABS_Mapped_Throttle
;FE_Motor_RPM	equals ABS_Motor_RPM
;FE_Motor_Temp	equals Motor_Temperature
;FE_Key_Vol		equals Keyswitch_Voltage
;FE_Bat_A		equals Battery_Current
;FE_Bat_A_D		equals Battery_Current_Display
;FE_Controller_Temp	equals Controller_Temperature
;FE_Controller_Temp_Cutback equals ControllerTempCutback
;FE_Current_RMS	equals Current_RMS
;FE_Current_Request	equals Current_Request

;FE_VCL_Throttle	equals VCL_Throttle
;FE_VCL_Brake	equals VCL_Brake

;------------ Setup mailboxes ----------------------------
disable_mailbox(pdoSend)
Shutdown_CAN_Cyclic()

Setup_Mailbox(pdoSend, 0, 0, 0x566, C_CYCLIC, C_XMT, 0, 0)
Setup_Mailbox_Data(pdoSend,8,
                    @Capacitor_Voltage + USEHB,
					@Capacitor_Voltage,
					@ABS_Motor_RPM + USEHB,
					@ABS_Motor_RPM,
					@Motor_Temperature + USEHB,
					@Motor_Temperature,
					@ABS_Mapped_Throttle + USEHB,
					@ABS_Mapped_Throttle)

enable_mailbox(pdoSend)

disable_mailbox(debug)

Setup_Mailbox(debug, 0, 0, 0x466, C_CYCLIC, C_XMT, 0, 0)
Setup_Mailbox_Data(debug,8,
					@SetInterlock,
                    @HVRequest,
					@state,
					@PWM1_Output,
					@PWM2_Output,
					@PWM3_Output,
					@VCL_Throttle,
					@VCL_Brake)

enable_mailbox(debug)

disable_mailbox(pdoAck)
Setup_Mailbox(pdoAck, 0, 0, 0x666, C_EVENT, C_XMT, 0, 0)
Setup_Mailbox_Data(pdoAck,8,
					0xFF,
                    @Keyswitch_Voltage + USEHB,
                    @Keyswitch_Voltage,
					@Battery_Current + USEHB,
					@Battery_Current,
					@Battery_Current_Display,
					@Controller_Temperature + USEHB,
					@Controller_Temperature
)
enable_mailbox(pdoAck)

;disable_mailbox(pdoInfo)
;Setup_Mailbox(pdoInfo, 0, 0, 0x866, C_EVENT, C_XMT, 0, 0)
;Setup_Mailbox_Data(pdoInfo,8,
;					@ControllerTempCutback + USEHB,
;					@ControllerTempCutback,
;					@Current_RMS + USEHB,
;					@Current_RMS,
;					@Current_Request + USEHB,
;					@Current_Request,
;					0,
;					0
;)
;enable_mailbox(pdoInfo)

disable_mailbox(eStop)
Setup_Mailbox(eStop, 0, 0, 0x366, C_CYCLIC, C_XMT, 0, 0)
Setup_Mailbox_Data(eStop,8,
					@e_stop,
					0,
					0,
					0,
					0,
					0,
					0,
					0
)
enable_mailbox(eStop)

Setup_Mailbox(pdoRecv, 0, 0, 0x766, C_EVENT, C_RCV, 0, pdoAck)
Setup_Mailbox_Data(pdoRecv,8,
					@SetInterlock,
                    @throttle_high,
					@throttle_low,
					0,
					@e_stop_check,
					0,
					@SOC,
					@BMS_temp)

Startup_CAN()
CAN_Set_Cyclic_Rate( 30 );actually 120ms
Setup_NMT_State(ENTER_OPERATIONAL)			;Set NMT state so we can detect global NMT commands
Startup_CAN_Cyclic()

; The following statements make it so that precharge always takes approximately 4 seconds
Precharge_Time = 1000 ; Changes this to 4 seconds, safely close the contacter 

precharge_drop_threshold = -1920 ; should be -30 in TACT

Mainloop:

;--------------- Relays Control -----------------------------
;--------------- Mirror driver 1-> driver 5 -----------------
;--------------- and driver 3 -> driver 4 -------------------


; PWM stops two drivers from doing the same thing by swaping the drivers  

	if(PWM3_Output > 0){ ;100%
		put_pwm(PWM4, 0x7fff)
	}
	else{
		put_pwm(PWM4, 0x0) ;0
	}

	if(PWM1_Output > 0){ ;used as binary states, relay controls 
		put_pwm(PWM5, 0x7fff)
	}
	else{
  	put_pwm(PWM5, 0)
	}


;---------------- Interlock State Machine --------------------
; if all necssary depencies of request fulfilled now we can start spnning the motor 
; Parameter defintions set up internally

	if(state = 0)		; Interlock OFF
	{
		; ensures that there is a person present and controls the main contactor
		; interlock is when high voltage in enabled--we can spin the wheel 

		Clear_interlock()
		; LED driver in order dashboards
		put_pwm(PWM2,0)

		if((SetInterlock > 0) & (e_stop_check = 0))	; if interlock request observed, go to interlock state
		{
			state = 1
		}
	}
	else if(state = 1)	; Interlock ON, requested by CAN message
	{
		; closes the contactor 
		Set_interlock()


		if(((throttle_high*255 + throttle_low) < 0) or ((throttle_high*255 + throttle_low) > 32767)) ; if throttle signal out of bounds, reset it to zero
		{
			VCL_Throttle = 0
		}
    	else
		{
			VCL_Throttle = (throttle_high*255 + throttle_low)
	  	}

		; state in the dash has changed go back to state zero
		if(SetInterlock = 0)	; if interlock request is not observed, go back to pre-interlock state
		{
			state = 0;
		}

		; e-stop has been hit
		if(Status3 = 36) ; an OS defined variable that has info on driver faults
		{
			state = 3
			e_stop = 1
			send_mailbox(eStop)
		}

		else if(Status3 > 0) 
		{
			state = 2; ; trap state
		}
	}
	else if(state = 2)	; Trap state. No exit conditions. DO NOT TOUCH!!!!!!!
	{
		Clear_interlock()
		put_pwm(PWM2, 0)
	} 

	else if(state = 3) ; handle estop
	{
		if(e_stop_check = 1)
		{
			state = 0
			e_stop = 0
			send_mailbox(eStop)
		}
	}

goto Mainloop