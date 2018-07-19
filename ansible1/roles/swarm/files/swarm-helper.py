#!/usr/bin/env python
from bottle import get, run, abort
from subprocess import check_output
from socket import gethostname
from signal import signal, setitimer, ITIMER_REAL, SIGALRM

def cleanup(signum, frame):
  try:
   nodes = check_output('docker node ls', shell=True).strip()
   down = map(lambda x: x.split()[1], filter(lambda x: 'Down' in x, nodes.split("\n")))
   for node in down:
    check_output('docker node rm ' + node, shell=True)
  except:
   pass

@get("/join/worker")
def token():
  return check_output('docker swarm join-token -q worker', shell=True).strip()

@get("/join/master")
def token():
  return check_output('docker swarm join-token -q master', shell=True).strip()
     
@get("/drain/<hostname>")
def drain(hostname):
  try:
   return check_output('docker node update --availability drain ' + hostname, shell=True).strip()
  except:
   abort(404, "node not found")
        
if gethostname() == 'docker-swarm-mgr':
    try:
     check_output('docker swarm init', shell=True)
    except:
     pass
signal(SIGALRM, cleanup)
setitimer(ITIMER_REAL, 10, 10)
run(port=1337,host='0.0.0.0')
