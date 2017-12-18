mtype = {invite, trying, ringing, ok, ack, cancel, canceled, bye, inviteSuccess, inviteFail, serverError };

/* two agents:a, b; two proxies:pone, ptwo */
chan a2pone = [4] of {mtype};
chan pone2a = [4] of {mtype};
chan pone2ptwo = [4] of {mtype};
chan ptwo2pone = [4] of {mtype};
chan ptwo2b = [4] of {mtype};
chan b2ptwo = [4] of {mtype};
chan a2b = [4] of {mtype};
chan b2a = [4] of {mtype};

active proctype agentA() {
	idle:
		if
		:: a2pone!invite;goto inviting;
		:: pone2a?invite -> a2pone!ringing; goto userres;
		fi;
	inviting:
	    if
	    :: pone2a?invite -> a2pone!ringing;
	       do
	       ::if
	         :: pone2a?trying -> 
	            do
	            :: printf("trying\n"); break;
	            :: a2pone!cancel; goto canceling;
	            od;
	         :: pone2a?ringing -> 
	            do
	            :: printf("ringing\n"); break;
	            :: a2pone!cancel; goto canceling;
	            od;
	         :: pone2a?ok -> printf("ok\n"); goto send_ack;
	         fi;  
	        :: goto userres;
	        od;
        :: pone2a?trying -> 
	       do
	       :: printf("trying\n"); break;
	       :: a2pone!cancel; goto canceling;
	       od;
	    :: pone2a?ringing -> 
	       do
	       :: printf("ringing\n"); break;
	       :: a2pone!cancel; goto canceling;
	       od;
	    :: pone2a?ok -> printf("ok\n"); goto send_ack;
	    fi;   
	send_ack:
		if
		:: a2b!ack -> goto mediaSession;
		fi;
    wait_ack:
        if
        :: b2a?ack -> goto mediaSession;
        fi;
	mediaSession:
		if
		:: b2a?bye -> a2b!ok; goto idle;
		:: a2b!bye -> goto terminating;
		fi;
	userres:
	    if 
	    :: pone2a?cancel -> a2pone!canceled; goto inviting;
	    :: do
	       :: a2pone!ok -> goto wait_ack; /* user accept the request. */
	       :: a2pone!inviteFail -> goto idle; /* user is busy or not willing to take the call */
	       :: a2pone!serverError-> goto idle; /* sever error to fulfill a request. */
	       od;
	    fi;
	canceling:
	    if
	    :: pone2a?canceled-> goto idle;
	    fi;
	terminating:
	    if
	    :: a2b?ok -> goto idle;
	    fi; 
}   

active proctype pone() {
        do
	    :: a2pone?invite -> pone2ptwo!invite; pone2a!trying;      
        :: ptwo2pone?invite -> pone2a!invite; pone2ptwo!trying;      	   
		:: a2pone?cancel -> pone2ptwo!cancel; pone2a!canceled; 
	    :: ptwo2pone?cancel -> pone2a!cancel; pone2ptwo!canceled; 
	    :: a2pone?ringing -> pone2ptwo!ringing; 
		:: a2pone?ok -> pone2ptwo!ok; 
		:: a2pone?inviteFail -> pone2ptwo!inviteFail;
		:: a2pone?serverError -> pone2ptwo!serverError; 
		:: ptwo2pone?trying -> skip;
		:: ptwo2pone?ringing -> pone2a!ringing; 
		:: ptwo2pone?ok -> pone2a!ok; 
		:: ptwo2pone?inviteFail -> pone2a!inviteFail; 
		:: ptwo2pone?serverError -> pone2a!serverError; 
		:: ptwo2pone?canceled-> skip;
		:: a2pone?canceled -> skip;
        od;	    
}

active proctype ptwo() {
        do
	    :: b2ptwo?invite -> ptwo2pone!invite; ptwo2b!trying;   
        :: pone2ptwo?invite -> ptwo2b!invite; ptwo2pone!trying;      	   
		:: b2ptwo?cancel -> ptwo2pone!cancel; ptwo2b!canceled; 
		:: pone2ptwo?cancel -> ptwo2b!cancel; ptwo2pone!canceled; 
		:: b2ptwo?ringing -> ptwo2pone!ringing; 
		:: b2ptwo?ok -> ptwo2pone!ok;
		:: b2ptwo?inviteFail -> ptwo2pone!inviteFail; 
		:: b2ptwo?serverError -> ptwo2pone!serverError; 
		:: pone2ptwo?trying -> skip;
		:: pone2ptwo?ringing -> ptwo2b!ringing;
		:: pone2ptwo?ok -> ptwo2b!ok; 
		:: pone2ptwo?inviteFail -> ptwo2b!inviteFail; 
		:: pone2ptwo?serverError -> ptwo2b!serverError; 
		:: pone2ptwo?canceled -> skip;
		:: b2ptwo?canceled -> skip;
        od;    
}

active proctype agentB() {
	idle:
		if
		:: b2ptwo!invite;goto inviting;
		:: ptwo2b?invite -> b2ptwo!ringing; goto userres;
		fi;
	inviting:
	    if
	    :: ptwo2b?invite -> b2ptwo!ringing;
	       do
	       ::if
	         :: ptwo2b?trying -> 
	           do
	           :: printf("trying\n"); break;
	           :: b2ptwo!cancel; goto canceling;
	           od;
	         :: ptwo2b?ringing -> 
	            do
	            ::printf("ringing\n"); break;
	            :: b2ptwo!cancel; goto canceling;
	            od;
	         :: ptwo2b?ok -> printf("ok\n"); goto send_ack;
	         fi;
	        :: goto userres;
	        od;
	    :: ptwo2b?trying -> 
	          do
	          :: printf("trying\n"); break;
	          :: b2ptwo!cancel; goto canceling;
	          od;
	    :: ptwo2b?ringing -> 
	          do
	          ::printf("ringing\n"); break;
	          :: b2ptwo!cancel; goto canceling;
	          od;
	    :: ptwo2b?ok -> printf("ok\n"); goto send_ack;
	    fi;   
	send_ack:
		if
		:: b2a!ack -> goto mediaSession;
		fi;
    wait_ack:
        if
        :: a2b?ack -> goto mediaSession;
        fi;
	mediaSession:
		if
		:: a2b?bye -> b2a!ok; goto idle;
		:: b2a!bye -> goto terminating;
		fi;
	userres: 
		if 
	    :: ptwo2b?cancel -> b2ptwo!canceled; goto inviting;
	    :: do
	       :: b2ptwo!ok -> goto wait_ack;  /* user accept the request. */
	       :: b2ptwo!inviteFail-> goto idle;  /* user is busy or not willing to take the call */
	       :: b2ptwo!serverError-> goto idle;/* sever error to fulfill a request. */
	       od;
	    fi;
	terminating:
	    if
	    :: a2b?ok -> goto idle;
	    fi;
	canceling:
	    if
	    :: ptwo2b?canceled-> goto idle;
	    fi;
}   
