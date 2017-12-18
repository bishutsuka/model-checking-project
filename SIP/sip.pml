mtype = {invite, trying, sessionProgress, ok, ack, cancel, bye, inviteSuccess, inviteFail, serverError };

/* 2 channels for TCP communication */
chan client2proxy = [1] of {mtype};
chan proxy2server = [1] of {mtype};
chan server2proxy = [1] of {mtype};
chan proxy2client = [1] of {mtype};

active proctype client() {
	inviting:
		if
		:: client2proxy!invite;	goto waiting_for_trying;
		fi;
	waiting_for_trying:
		if
		:: proxy2client?trying -> goto waiting_for_session_progress;
		fi;
	waiting_for_session_progress:
		if
		:: proxy2client?sessionProgress -> goto waiting_for_ok;
		fi;
	waiting_for_ok:
		if
		:: proxy2client?ok -> goto send_ack;
		fi;
	send_ack:
		if
		:: client2proxy!ack -> goto waiting_for_bye;
		fi;
	waiting_for_bye:
		if
		:: proxy2client?bye -> client2proxy!ok; goto inviting;
		fi;
}

active proctype proxy() {
	waiting_for_invite:
		if
		:: client2proxy?invite -> proxy2client!trying; goto invite_server;
		fi;
	invite_server:
		if
		:: proxy2server!invite -> goto waiting_for_session_progress;
		fi;
	waiting_for_session_progress:
		if
		:: server2proxy?sessionProgress -> proxy2client!sessionProgress; goto waiting_for_ok;
		fi;
	waiting_for_ok:
		if
		:: server2proxy?ok -> proxy2client!ok; goto waiting_for_ack;
		fi;
	waiting_for_ack:
		if
		:: client2proxy?ack -> proxy2server!ack; goto waiting_for_bye;
		fi;
	waiting_for_bye:
		if
		:: server2proxy?bye -> proxy2client!bye; goto waiting_for_closing_ok;
		fi;
	waiting_for_closing_ok:
		if
		:: client2proxy?ok -> proxy2server!ok; goto waiting_for_invite;
		fi;
}


active proctype server() {
	waiting_for_invite:
		if
		:: proxy2server?invite -> server2proxy!sessionProgress; goto send_status_ok;
		fi;
	send_status_ok:
		if
		:: server2proxy!ok -> goto waiting_for_ack;
		fi;
	waiting_for_ack:
		if
		:: proxy2server?ack -> server2proxy!bye; goto waiting_for_ok;
		fi;
	waiting_for_ok:
		if 
		:: proxy2server?ok -> goto waiting_for_invite;
		fi;
}

