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
bool cancelsent[2];


proctype agent(byte i) {
    byte j = (i + 1) % 2;
    invitesent[i]=0;
    cancelsent[i]=0;
	/* idle: choose client or server behavior */
	idle:
	    if
	    :: atomic{proxy2agent[i]?invite -> goto invite_status;}
	    :: atomic{proxy2agent[i]?cancel -> agent2proxy[i]!canceled; goto idle;}
	    :: atomic{agent2agent[i]?ack -> goto media_session_server;}	
	    :: atomic{proxy2agent[i]?trying -> if
		                                   :: atomic{cancelsent[i] == 1 -> goto waiting_for_canceled;}
		                                   :: do 
		                                      :: atomic{cancelsent[i] == 0 -> goto waiting_for_session_progress;}		/* receive trying from proxy */
		                                      :: atomic{cancelsent[i] == 0 ->agent2proxy[i]!cancel; cancelsent[i]=1; goto waiting_for_canceled;}	/* cancel session initiation */
		                                      od;
		                                   fi;}	
	    :: atomic{proxy2agent[i]?sessionProgress -> if
		                                            :: atomic { cancelsent[i] == 1 -> goto waiting_for_canceled;}
		                                            :: do 
		                                               :: atomic { cancelsent[i] == 0 -> goto waiting_for_ok;}						/* session progress */
		                                               :: atomic{cancelsent[i] == 0 -> agent2proxy[i]!cancel; cancelsent[i]=1; goto waiting_for_canceled;}	/* cancel session initiation */
		                                               od;
		                                            fi;}
		:: atomic{proxy2agent[i]?ok -> if 
		                               :: atomic{cancelsent[i] == 1 -> goto waiting_for_canceled;}
		                               :: do 
		                                  :: atomic {cancelsent[i] == 0 -> agent2agent[j]!ack; goto media_session_client;}				/* session is initiated */
		                                  :: atomic {cancelsent[i] == 0 ->agent2proxy[i]!cancel; cancelsent[i]=1; goto waiting_for_canceled;}	/* cancel session initiation */
		                                  od;
		                               fi;}
	    :: atomic{proxy2agent[i]?inviteFail -> if
	                                           :: atomic { cancelsent[i] == 0; invitesent[i]=0; goto idle;}					/* invitation rejected */
	                                           :: atomic { cancelsent[i] == 1; goto waiting_for_canceled;}
	                                           fi;}				/* invitation rejected */	
	    :: atomic{proxy2agent[i]?serverError -> if 
		                                        :: atomic{ cancelsent[i] == 1 -> goto waiting_for_canceled;}
		                                        :: atomic{ cancelsent[i] == 0 -> invitesent[i]=0; goto idle;}					/* server error */
		                                        fi;}	
	    :: atomic{proxy2agent[i]?canceling -> goto waiting_for_canceled;}                                      
	    :: atomic{proxy2agent[i]?canceled -> invitesent[i]=0; cancelsent[i]=0; goto idle;} /* her invite canceled, I goback for server to idle, my invite canceled. */
		::do
		  :: atomic{invitesent[i] == 0 -> goto inviting;} 	
		  od;				
		fi;
	/* client behavior */
	inviting:
		if
		:: atomic{agent2proxy[i]!invite; invitesent[i]=1; do
		                                                  :: goto waiting_for_trying; 
		                                                  :: atomic{cancelsent[i] == 0 ->agent2proxy[i]!cancel; cancelsent[i]=1; goto waiting_for_canceled;}	/* cancel session initiation */
		                                                  od;}						
		fi;
	waiting_for_trying:
		if
		:: atomic{proxy2agent[i]?invite -> goto invite_status;}
		:: atomic{proxy2agent[i]?cancel -> agent2proxy[i]!canceled; goto waiting_for_trying;}
		:: atomic{agent2agent[i]?ack -> goto media_session_server;}	
		:: atomic{agent2agent[i]?byeOk -> invitesent[j]=0; goto waiting_for_trying;}
		:: atomic{proxy2agent[i]?canceling -> goto waiting_for_canceled;}
		:: atomic{proxy2agent[i]?trying -> if
		                                   :: atomic{cancelsent[i] == 1 -> goto waiting_for_canceled;}
		                                   :: do 
		                                      :: atomic{cancelsent[i] == 0 -> goto waiting_for_session_progress;}		/* receive trying from proxy */
		                                      :: atomic{cancelsent[i] == 0 ->agent2proxy[i]!cancel; cancelsent[i]=1; goto waiting_for_canceled;}	/* cancel session initiation */
		                                      od;
		                                   fi;}	
		fi;
	waiting_for_session_progress:
		if
		:: atomic{proxy2agent[i]?invite -> goto invite_status;}
		:: atomic{proxy2agent[i]?cancel -> agent2proxy[i]!canceled; goto waiting_for_session_progress;}
		:: atomic{agent2agent[i]?ack -> goto media_session_server;}					/* session is initiated */
		:: atomic{agent2agent[i]?byeOk -> invitesent[j]=0;goto waiting_for_session_progress;}
		:: atomic{proxy2agent[i]?canceling -> goto waiting_for_canceled;}
		:: atomic{proxy2agent[i]?sessionProgress -> if
		                                            :: atomic { cancelsent[i] == 1 -> goto waiting_for_canceled;}
		                                            :: do 
		                                               :: atomic { cancelsent[i] == 0 -> goto waiting_for_ok;}						/* session progress */
		                                               :: atomic{cancelsent[i] == 0 -> agent2proxy[i]!cancel; cancelsent[i]=1; goto waiting_for_canceled;}	/* cancel session initiation */
		                                               od;
		                                            fi;}
		:: atomic{proxy2agent[i]?serverError -> if 
		                                        :: atomic{ cancelsent[i] == 1 -> goto waiting_for_canceled;}
		                                        :: atomic{ cancelsent[i] == 0 -> invitesent[i]=0; goto idle;}					/* server error */
		                                        fi;}
		fi;
	waiting_for_ok:
		if
		:: atomic{proxy2agent[i]?invite -> goto invite_status;}
		:: atomic{agent2agent[i]?ack -> goto media_session_server;}	
		:: atomic{agent2agent[i]?byeOk -> invitesent[j]=0; goto waiting_for_ok;}
		:: atomic{proxy2agent[i]?canceling -> goto waiting_for_canceled;}
		:: atomic{proxy2agent[i]?ok -> if 
		                               :: atomic{cancelsent[i] == 1 -> goto waiting_for_canceled;}
		                               :: do 
		                                  :: atomic {cancelsent[i] == 0 -> agent2agent[j]!ack; goto media_session_client;}				/* session is initiated */
		                                  :: atomic {cancelsent[i] == 0 -> agent2proxy[i]!cancel; cancelsent[i]=1; goto waiting_for_canceled;}	/* cancel session initiation */
		                                  od;
		                               fi;}
	    :: atomic{proxy2agent[i]?inviteFail -> if
	                                           :: atomic { cancelsent[i] == 0; invitesent[i]=0; goto idle;}					/* invitation rejected */
	                                           :: atomic { cancelsent[i] == 1; goto waiting_for_canceled;}
	                                           fi;}
		fi;
	media_session_client:
		goto waiting_for_bye;
		
	waiting_for_bye:
		if
		:: atomic{agent2agent[i]?byeOk -> invitesent[j]=0; goto waiting_for_bye;}
		:: atomic {agent2agent[i]?ack -> goto media_session_server;}
		:: atomic{agent2agent[i]?bye -> agent2agent[j]!byeOk; goto idle;}				/* session terminated */
		fi;
		
    waiting_for_canceled:
        if
	    :: atomic{proxy2agent[i]?invite -> goto invite_status;}	 
	    :: atomic{proxy2agent[i]?trying -> goto waiting_for_canceled;}
	    :: atomic{proxy2agent[i]?sessionProgress -> goto waiting_for_canceled;}
	    :: atomic{proxy2agent[i]?serverError -> goto waiting_for_canceled;}
	    :: atomic{proxy2agent[i]?ok -> goto waiting_for_canceled;}
	    :: atomic{proxy2agent[i]?inviteFail -> goto waiting_for_canceled;}
	    :: atomic{agent2agent[i]?byeOk -> invitesent[j]=0; goto waiting_for_canceled;}
	    :: atomic{agent2agent[i]?ack -> goto media_session_server;}
	    :: atomic{proxy2agent[i]?cancel -> agent2proxy[i]!canceled; goto waiting_for_canceled;}
	    :: atomic{proxy2agent[i]?canceling -> goto waiting_for_canceled;}
	    :: atomic{proxy2agent[i]?canceled -> invitesent[i]=0; cancelsent[i]=0; goto idle;}	    
	    fi;
	/* server behavior */	
	invite_status:
	    do
		:: atomic{agent2proxy[i]!sessionProgress; goto server_response;} 	/* response to the invite request */
		:: atomic{agent2proxy[i]!serverError; goto idle;}			/* server error */
		od;

	server_response:
	    do
	    :: atomic{agent2proxy[i]!ok -> goto waiting_for_ack;}
		:: atomic{agent2proxy[i]!inviteFail; goto idle;} 			/* reject invite request */
		od;		
	waiting_for_ack:
		if
		:: atomic{proxy2agent[i]?trying -> if
		                                   :: atomic{cancelsent[i] == 1 -> goto waiting_for_canceled;}
		                                   :: do 
		                                      :: atomic{cancelsent[i] == 0 -> goto waiting_for_session_progress;}		/* receive trying from proxy */
		                                      :: atomic{cancelsent[i] == 0 ->agent2proxy[i]!cancel; cancelsent[i]=1; goto waiting_for_canceled;}	/* cancel session initiation */
		                                      od;
		                                   fi;}	
	    :: atomic{proxy2agent[i]?sessionProgress -> if
		                                            :: atomic { cancelsent[i] == 1 -> goto waiting_for_canceled;}
		                                            :: do 
		                                               :: atomic { cancelsent[i] == 0 -> goto waiting_for_ok;}						/* session progress */
		                                               :: atomic{cancelsent[i] == 0 -> agent2proxy[i]!cancel; cancelsent[i]=1; goto waiting_for_canceled;}	/* cancel session initiation */
		                                               od;
		                                            fi;}
		:: atomic{proxy2agent[i]?serverError -> if 
		                                        :: atomic{ cancelsent[i] == 1 -> goto waiting_for_canceled;}
		                                        :: atomic{ cancelsent[i] == 0 -> invitesent[i]=0; goto idle;}					/* server error */
		                                        fi;}                                 
	    :: atomic{proxy2agent[i]?inviteFail -> if
	                                           :: atomic { cancelsent[i] == 0; invitesent[i]=0; goto idle;}					/* invitation rejected */
	                                           :: atomic { cancelsent[i] == 1; goto waiting_for_canceled;}
	                                           fi;}	
	    :: atomic{proxy2agent[i]?canceling -> goto waiting_for_ack;}
	    :: atomic{proxy2agent[i]?canceled -> invitesent[i]=0; cancelsent[i]=0;goto waiting_for_ack;}
		:: atomic{proxy2agent[i]?cancel -> agent2proxy[i]!canceled; goto idle;} 					/* canceled by client */
		:: atomic{agent2agent[i]?ack -> goto media_session_server;}					/* session is initiated */
		fi;
		
	media_session_server:
	    do
	    :: atomic{agent2agent[j]!bye; goto waiting_for_session_termination;}
	    od;
		
	waiting_for_session_termination:
		if 
		:: atomic{proxy2agent[i]?trying -> if
		                                   :: atomic{cancelsent[i] == 1 -> goto waiting_for_canceled;}
		                                   :: do 
		                                      :: atomic{cancelsent[i] == 0 -> goto waiting_for_session_progress;}		/* receive trying from proxy */
		                                      :: atomic{cancelsent[i] == 0 ->agent2proxy[i]!cancel; cancelsent[i]=1; goto waiting_for_canceled;}	/* cancel session initiation */
		                                      od;
		                                   fi;}	
	    :: atomic{proxy2agent[i]?sessionProgress -> if
		                                            :: atomic { cancelsent[i] == 1 -> goto waiting_for_canceled;}
		                                            :: do 
		                                               :: atomic { cancelsent[i] == 0 -> goto waiting_for_ok;}						/* session progress */
		                                               :: atomic{cancelsent[i] == 0 -> agent2proxy[i]!cancel; cancelsent[i]=1; goto waiting_for_canceled;}	/* cancel session initiation */
		                                               od;
		                                            fi;}
		:: atomic{proxy2agent[i]?serverError -> if 
		                                        :: atomic{ cancelsent[i] == 1 -> goto waiting_for_canceled;}
		                                        :: atomic{ cancelsent[i] == 0 -> invitesent[i]=0; goto idle;}					/* server error */
		                                        fi;}                                  
	    :: atomic{proxy2agent[i]?ok -> if 
		                               :: atomic{cancelsent[i] == 1 -> goto waiting_for_canceled;}
		                               :: do 
		                                  :: atomic {cancelsent[i] == 0 -> agent2agent[j]!ack; goto media_session_client;}				/* session is initiated */
		                                  :: atomic {cancelsent[i] == 0 ->agent2proxy[i]!cancel; cancelsent[i]=1; goto waiting_for_canceled;}	/* cancel session initiation */
		                                  od;
		                               fi;}
	    :: atomic{proxy2agent[i]?inviteFail -> if
	                                           :: atomic { cancelsent[i] == 0; invitesent[i]=0; goto idle;}					/* invitation rejected */
	                                           :: atomic { cancelsent[i] == 1; goto waiting_for_canceled;}
	                                           fi;}	
	    :: atomic{proxy2agent[i]?canceling -> goto waiting_for_session_termination;}
	    :: atomic{proxy2agent[i]?canceled -> invitesent[i]=0; cancelsent[i]=0;goto waiting_for_session_termination;}
	    :: atomic{agent2agent[i]?bye -> agent2agent[j]!byeOk; goto waiting_for_session_termination;}
		:: atomic{agent2agent[i]?byeOk -> invitesent[j]=0; goto idle;}							/* session terminated */
		fi;
}

proctype proxy(byte i) {
	byte j = (i + 1) % 2; /* other proxy id */
	
	do
	/* agent <-> this proxy <-> other proxy */
	:: atomic {agent2proxy[i]?invite -> proxy2agent[i]!trying; proxy2proxy[i]!invite;}
	:: atomic {proxy2proxy[j]?sessionProgress -> proxy2agent[i]!sessionProgress;} 	/* session progress */
	:: atomic {proxy2proxy[j]?inviteFail -> proxy2agent[i]!inviteFail;} 				/* invite failed */
	:: atomic {proxy2proxy[j]?serverError -> proxy2agent[i]!serverError;} 			/* server error */
	:: atomic {agent2proxy[i]?cancel -> proxy2agent[i]!canceling; proxy2proxy[i]!cancel;}/* cancel */ 
	:: atomic {proxy2proxy[j]?canceled -> proxy2agent[i]!canceled;}
	:: proxy2proxy[j]?canceling;	
	:: atomic {proxy2proxy[j]?ok -> proxy2agent[i]!ok;}
	/* other proxy <-> this proxy <-> agent */
	:: atomic {proxy2proxy[j]?invite -> proxy2proxy[i]!trying; proxy2agent[i]!invite;}
	:: atomic {agent2proxy[i]?sessionProgress -> proxy2proxy[i]!sessionProgress;}	/* session progress */
	:: atomic {agent2proxy[i]?inviteFail -> proxy2proxy[i]!inviteFail;}				/* invite failed */
	:: atomic {agent2proxy[i]?serverError -> proxy2proxy[i]!serverError;}			/* server error */
	:: atomic {proxy2proxy[j]?cancel -> proxy2proxy[i]!canceling; proxy2agent[i]!cancel;	}							
	:: atomic {agent2proxy[i]?canceled -> proxy2proxy[i]!canceled;}
	:: atomic {agent2proxy[i]?ok -> proxy2proxy[i]!ok;}
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
ltl p1 {<> (agent[0]@media_session_client && agent[0]@media_session_server)}
