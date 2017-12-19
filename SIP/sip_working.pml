/*
 * PROMELA model for the Session Initiation Protocol (SIP).
 *
 * by Y. Wang and F. Marquart
 * 2017/12/19
 */

mtype = {invite, trying, sessionProgress, ok, ack, cancel, bye, byeOk, inviteFail, serverError };

/* channels for communication */
chan agent2proxy[2] = [4] of { mtype };
chan proxy2agent[2] = [4] of { mtype };
chan proxy2proxy[2] = [4] of { mtype };
chan agent2agent = [4] of { mtype };

byte sem = 1;

proctype agent(byte i) {
	/* idle: choose client or server behavior */
	idle:
		if 
		:: (sem == i) -> goto inviting; 					
		:: (sem != i) -> goto waiting_for_invite;
		fi;
		
	/* client behavior */
	inviting:
		if
		:: agent2proxy[i]!invite; goto waiting_for_trying;						/* send invite request */
		fi;
	waiting_for_trying:
		if
		:: proxy2agent[i]?trying -> goto waiting_for_session_progress;		/* receive trying from proxy */
		fi;
	waiting_for_session_progress:
		if
		:: proxy2agent[i]?sessionProgress -> goto waiting_for_ok;						/* session progress */
		:: proxy2agent[i]?inviteFail -> sem = (i + 1) % 2; goto idle;					/* invitation rejected */
		:: proxy2agent[i]?serverError -> sem = (i + 1) % 2; goto idle;					/* server error */
		fi;
	waiting_for_ok:
		if
		:: proxy2agent[i]?ok -> agent2agent!ack; goto media_session_client;				/* session is initiated */
		:: proxy2agent[i]?ok -> agent2proxy[i]!cancel; sem = (i + 1) % 2; goto idle;	/* cancel session initiation */
		fi;
	media_session_client:
		goto waiting_for_bye;
		
	waiting_for_bye:
		if
		:: agent2agent?bye -> agent2agent!byeOk; sem = (i + 1) % 2; goto idle;				/* session terminated */
		fi;
		
	/* server behavior */	
	waiting_for_invite:
		if
		:: proxy2agent[i]?invite -> agent2proxy[i]!sessionProgress; goto send_status_ok; 	/* accept invite request */
		:: proxy2agent[i]?invite -> agent2proxy[i]!inviteFail; sem = i;	goto idle; 			/* reject invite request */
		:: proxy2agent[i]?invite -> agent2proxy[i]!serverError; sem = i; goto idle;			/* server error */
		fi;
	send_status_ok:
		if
		:: agent2proxy[i]!ok -> goto waiting_for_ack;
		fi;
		
	waiting_for_ack:
		if
		:: proxy2agent[i]?cancel -> sem = i; goto idle; 					/* canceled by client */
		:: agent2agent?ack -> goto media_session_server;					/* session is initiated */
		fi;
		
	media_session_server:
		agent2agent!bye; goto waiting_for_session_termination;
		
	waiting_for_session_termination:
		if 
		:: agent2agent?byeOk -> sem = i; goto idle;							/* session terminated */
		fi;
}

proctype proxy(byte i) {
	byte j = (i + 1) % 2; /* other proxy id */
	
	do
	/* agent <-> this proxy <-> other proxy */
	:: agent2proxy[i]?invite -> proxy2agent[i]!trying; proxy2proxy[i]!invite;
	:: proxy2proxy[j]?sessionProgress -> proxy2agent[i]!sessionProgress; 	/* session progress */
	:: proxy2proxy[j]?inviteFail -> proxy2agent[i]!inviteFail; 				/* invite failed */
	:: proxy2proxy[j]?serverError -> proxy2agent[i]!serverError; 			/* server error */
	:: agent2proxy[i]?cancel -> proxy2proxy[i]!cancel;						/* cancel */
	:: proxy2proxy[j]?ok -> proxy2agent[i]!ok;
	/* other proxy <-> this proxy <-> agent */
	:: proxy2proxy[j]?invite -> proxy2proxy[i]!trying; proxy2agent[i]!invite;
	:: agent2proxy[i]?sessionProgress -> proxy2proxy[i]!sessionProgress;	/* session progress */
	:: agent2proxy[i]?inviteFail -> proxy2proxy[i]!inviteFail;				/* invite failed */
	:: agent2proxy[i]?serverError -> proxy2proxy[i]!serverError;			/* server error */
	:: proxy2proxy[j]?cancel -> proxy2agent[i]!cancel;						/* cancel */
	:: agent2proxy[i]?ok -> proxy2proxy[i]!ok;
	/* remove trying from channel */
	:: proxy2proxy[j]?trying;
	od;
}


init {
	run agent(0);
	run proxy(0);
	run proxy(1);
	run agent(1);
}
