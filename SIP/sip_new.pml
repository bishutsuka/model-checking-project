/*
 * PROMELA model for the Session Initiation Protocol (SIP).
 *
 * by Y. Wang and F. Marquart
 * 2017/12/19
 */

mtype = {invite, trying, sessionProgress, ok, ack, cancel,canceling, canceled bye, byeOk, inviteFail, serverError };

/* channels for communication */
chan agent2proxy[2] = [4] of { mtype };
chan proxy2agent[2] = [4] of { mtype };
chan proxy2proxy[2] = [4] of { mtype };
chan agent2agent[2] = [4] of { mtype };
bool invitesent[2];


proctype agent(byte i) {
    byte j = (i + 1) % 2;
    invitesent[i]=0;
	/* idle: choose client or server behavior */
	idle:
	    if
	    :: proxy2agent[i]?invite -> goto invite_status;
	    :: proxy2agent[i]?cancel -> atomic{agent2proxy[i]!canceled; goto idle;}
	    :: agent2agent[i]?ack -> goto media_session_server;	
	    :: proxy2agent[i]?sessionProgress -> do 
		                                     :: goto waiting_for_ok;						/* session progress */
		                                     :: atomic{agent2proxy[i]!cancel; goto waiting_for_canceled;}	/* cancel session initiation */
		                                     od;
	    :: proxy2agent[i]?canceled -> atomic{invitesent[i]=0; goto idle;} /* her invite canceled, I goback for server to idle, my invite canceled. */
		:: invitesent[i] == 0 -> goto inviting; 					
		fi;
	/* client behavior */
	inviting:
		if
		:: atomic{agent2proxy[i]!invite; invitesent[i]=1; do
		                                                  :: goto waiting_for_trying; 
		                                                  :: atomic{agent2proxy[i]!cancel; goto waiting_for_canceled;}	/* cancel session initiation */
		                                                  od;}						
		fi;
	waiting_for_trying:
		if
		:: proxy2agent[i]?invite -> goto invite_status;
		:: proxy2agent[i]?cancel -> atomic{agent2proxy[i]!canceled; goto waiting_for_trying;}
		:: agent2agent[i]?ack -> goto media_session_server;	
		:: agent2agent[i]?byeOk -> atomic{invitesent[j]=0; goto waiting_for_trying;}
		:: proxy2agent[i]?trying -> do 
		                            :: goto waiting_for_session_progress;		/* receive trying from proxy */
		                            :: atomic{agent2proxy[i]!cancel; goto waiting_for_canceled;}	/* cancel session initiation */
		                            od;	
		fi;
	waiting_for_session_progress:
		if
		:: proxy2agent[i]?invite -> goto invite_status;
		:: proxy2agent[i]?cancel -> atomic{agent2proxy[i]!canceled; goto waiting_for_session_progress;}
		:: agent2agent[i]?ack -> goto media_session_server;					/* session is initiated */
		:: agent2agent[i]?byeOk -> atomic{invitesent[j]=0;goto waiting_for_session_progress;}
		:: proxy2agent[i]?sessionProgress -> do 
		                                     :: goto waiting_for_ok;						/* session progress */
		                                     :: atomic{agent2proxy[i]!cancel; goto waiting_for_canceled;}	/* cancel session initiation */
		                                     od;

		:: proxy2agent[i]?serverError -> invitesent[i]=0; goto idle;					/* server error */
		fi;
	waiting_for_ok:
		if
		:: proxy2agent[i]?invite -> goto invite_status;
		:: proxy2agent[i]?cancel -> atomic{agent2proxy[i]!canceled; goto waiting_for_ok;}
		:: agent2agent[i]?ack -> goto media_session_server;	
		:: agent2agent[i]?byeOk -> atomic{invitesent[j]=0; goto waiting_for_ok;}
		:: proxy2agent[i]?ok -> do 
		                        :: atomic {agent2agent[j]!ack; goto media_session_client;}				/* session is initiated */
		                        :: atomic{agent2proxy[i]!cancel; goto waiting_for_canceled;}	/* cancel session initiation */
		                        od;
	    :: proxy2agent[i]?inviteFail -> invitesent[i]=0; goto idle;					/* invitation rejected */
		fi;
	media_session_client:
		goto waiting_for_bye;
		
	waiting_for_bye:
		if
		:: agent2agent[i]?byeOk -> atomic{invitesent[j]=0; goto waiting_for_bye;}
		:: agent2agent[i]?bye -> atomic {agent2agent[j]!byeOk; goto idle;}				/* session terminated */
		fi;
		
    waiting_for_canceled:
        if
	    :: proxy2agent[i]?invite -> goto invite_status;	 
	    :: proxy2agent[i]?trying -> goto waiting_for_canceled;
	    :: proxy2agent[i]?sessionProgress -> goto waiting_for_canceled;
	    :: proxy2agent[i]?serverError -> goto waiting_for_canceled;
	    :: proxy2agent[i]?ok -> goto waiting_for_canceled;
	    :: proxy2agent[i]?inviteFail -> goto waiting_for_canceled;
	    :: agent2agent[i]?byeOk -> atomic{invitesent[j]=0; goto waiting_for_bye;}
	    :: proxy2agent[i]?canceling -> goto waiting_for_canceled;
	    :: proxy2agent[i]?canceled -> atomic{invitesent[i]=0; goto idle;}	    
	    fi;
	/* server behavior */	
	invite_status:
	    if
	    :: proxy2agent[i]?trying -> do 
		                            :: goto waiting_for_session_progress;		/* receive trying from proxy */
		                            :: atomic{agent2proxy[i]!cancel; goto waiting_for_canceled;}	/* cancel session initiation */
		                            od;	
	    :: proxy2agent[i]?sessionProgress -> do 
		                                     :: goto waiting_for_ok;						/* session progress */
		                                     :: atomic{agent2proxy[i]!cancel; goto waiting_for_canceled;}	/* cancel session initiation */
		                                     od;
	    :: proxy2agent[i]?serverError -> invitesent[i]=0; goto idle;					/* server error */                                     
	    :: proxy2agent[i]?ok -> do 
		                        :: atomic {agent2agent[j]!ack; goto media_session_client;}				/* session is initiated */
		                        :: atomic{agent2proxy[i]!cancel; goto waiting_for_canceled;}	/* cancel session initiation */
		                        od;
	    :: proxy2agent[i]?inviteFail -> invitesent[i]=0; goto idle;					/* invitation rejected */
	    ::do
		  :: agent2proxy[i]!sessionProgress; goto server_response; 	/* response to the invite request */
		  :: agent2proxy[i]!serverError; goto idle;			/* server error */
		  od;
		fi;
	server_response:
	    if
	    :: proxy2agent[i]?trying -> do 
		                            :: goto waiting_for_session_progress;		/* receive trying from proxy */
		                            :: atomic{agent2proxy[i]!cancel; goto waiting_for_canceled;}	/* cancel session initiation */
		                            od;	
	    :: proxy2agent[i]?sessionProgress -> do 
		                                     :: goto waiting_for_ok;						/* session progress */
		                                     :: atomic{agent2proxy[i]!cancel; goto waiting_for_canceled;}	/* cancel session initiation */
		                                     od;
		:: proxy2agent[i]?serverError -> invitesent[i]=0; goto idle;					/* server error */                                     
	    :: proxy2agent[i]?ok -> do 
		                        :: atomic {agent2agent[j]!ack; goto media_session_client;}				/* session is initiated */
		                        :: atomic{agent2proxy[i]!cancel; goto waiting_for_canceled;}	/* cancel session initiation */
		                        od;
	    :: proxy2agent[i]?inviteFail -> invitesent[i]=0; goto idle;		
	    :: proxy2agent[i]?cancel -> atomic{agent2proxy[i]!canceled; goto idle;} 					/* canceled by client */
		:: do
		   :: agent2proxy[i]!ok -> goto waiting_for_ack;
		   :: agent2proxy[i]!inviteFail; goto idle; 			/* reject invite request */
		   od;	
		fi;	
	waiting_for_ack:
		if
		:: proxy2agent[i]?trying -> do 
		                            :: goto waiting_for_session_progress;		/* receive trying from proxy */
		                            :: atomic{agent2proxy[i]!cancel; goto waiting_for_canceled;}	/* cancel session initiation */
		                            od;	
	    :: proxy2agent[i]?sessionProgress -> do 
		                                     :: goto waiting_for_ok;						/* session progress */
		                                     :: atomic{agent2proxy[i]!cancel; goto waiting_for_canceled;}	/* cancel session initiation */
		                                     od;
		:: proxy2agent[i]?serverError -> invitesent[i]=0; goto idle;					/* server error */                                     
	    :: proxy2agent[i]?ok -> do 
		                        :: atomic {agent2agent[j]!ack; goto media_session_client;}				/* session is initiated */
		                        :: atomic{agent2proxy[i]!cancel; goto waiting_for_canceled;}	/* cancel session initiation */
		                        od;
	    :: proxy2agent[i]?inviteFail -> invitesent[i]=0; goto idle;		
		:: proxy2agent[i]?cancel ->  atomic{agent2proxy[i]!canceled; goto idle;} 					/* canceled by client */
		:: agent2agent[i]?ack -> goto media_session_server;					/* session is initiated */
		fi;
		
	media_session_server:
	    do
	    :: atomic{agent2agent[j]!bye; goto waiting_for_session_termination;}
	    od;
		
	waiting_for_session_termination:
		if 
		:: proxy2agent[i]?trying -> do 
		                            :: goto waiting_for_session_progress;		/* receive trying from proxy */
		                            :: atomic{agent2proxy[i]!cancel; goto waiting_for_canceled;}	/* cancel session initiation */
		                            od;	
	    :: proxy2agent[i]?sessionProgress -> do 
		                                     :: goto waiting_for_ok;						/* session progress */
		                                     :: atomic{agent2proxy[i]!cancel; goto waiting_for_canceled;}	/* cancel session initiation */
		                                     od;
		:: proxy2agent[i]?serverError -> invitesent[i]=0; goto idle;					/* server error */                                     
	    :: proxy2agent[i]?ok -> do 
		                        :: atomic {agent2agent[j]!ack; goto media_session_client;}				/* session is initiated */
		                        :: atomic{agent2proxy[i]!cancel; goto waiting_for_canceled;}	/* cancel session initiation */
		                        od;
	    :: proxy2agent[i]?inviteFail -> invitesent[i]=0; goto idle;		
		:: agent2agent[i]?byeOk -> atomic {invitesent[j]=0; goto idle;}							/* session terminated */
		fi;
}

proctype proxy(byte i) {
	byte j = (i + 1) % 2; /* other proxy id */
	
	do
	/* agent <-> this proxy <-> other proxy */
	:: agent2proxy[i]?invite -> atomic{proxy2agent[i]!trying; proxy2proxy[i]!invite;}
	:: proxy2proxy[j]?sessionProgress -> proxy2agent[i]!sessionProgress; 	/* session progress */
	:: proxy2proxy[j]?inviteFail -> proxy2agent[i]!inviteFail; 				/* invite failed */
	:: proxy2proxy[j]?serverError -> proxy2agent[i]!serverError; 			/* server error */
	:: agent2proxy[i]?cancel -> atomic{proxy2agent[i]!canceling; proxy2proxy[i]!cancel;}/* cancel */ 
	:: proxy2proxy[j]?canceled -> proxy2agent[i]!canceled;
	:: proxy2proxy[j]?canceling;	
	:: proxy2proxy[j]?ok -> proxy2agent[i]!ok;
	/* other proxy <-> this proxy <-> agent */
	:: proxy2proxy[j]?invite -> atomic{proxy2proxy[i]!trying; proxy2agent[i]!invite;}
	:: agent2proxy[i]?sessionProgress -> proxy2proxy[i]!sessionProgress;	/* session progress */
	:: agent2proxy[i]?inviteFail -> proxy2proxy[i]!inviteFail;				/* invite failed */
	:: agent2proxy[i]?serverError -> proxy2proxy[i]!serverError;			/* server error */
	:: proxy2proxy[j]?cancel -> atomic{proxy2proxy[i]!canceling; proxy2agent[i]!cancel;	}					/*注意下这里,和之前不一样 cancel */		
	:: agent2proxy[i]?canceled -> proxy2proxy[i]!canceled;
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
