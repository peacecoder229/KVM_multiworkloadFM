import os, sys, time
import argparse

sys.path.append("/opt/trex-core/scripts/automation/trex_control_plane/stf/examples")
sys.path.append("/opt/trex-core/scripts/automation/trex_control_plane/stf/")

try:
    import stf_path
    from trex_stf_lib.trex_client import CTRexClient
except Exeption as e:
    print(e)
    print("Please make sure trex-core repo is cloned in /opt")
    print("git clone https://github.com/cisco-system-traffic-generator/trex-core /opt/trex-core")
    sys.exit(1)

def start(server, config):
    try:
        print('Connecting to {}'.format(server))
        trex_client = CTRexClient(server)

        if not trex_client.is_running():
            print('Connected, starting TRex ...')
            if config is None:
                cfg = '/etc/trex_cfg.yaml'
            else:
                trex_client.push_files(config)
                cfg = '{}/{}'.format(trex_client.get_trex_files_path(), config.split("/")[-1])

            trex_client.start_stateless(block_to_success = True, timeout = 40, user = None,
                                        cfg = cfg)
            print('...done')
        else:
            print('TRex is already running')
    except Exception as e:
        print(e)

def stop(server):
    try:
        print('Connecting to {}'.format(server))
        trex_client = CTRexClient(server)
        trex_client.force_kill(False)
        print('TRex is stopped.')
    except Exception as e:
        print(e)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Arguments for running TRex via daemon server')
    parser.add_argument('run', help='Start/Restart/Stop TRex', nargs='?', choices=('start', 'restart', 'stop'))
    parser.add_argument('--server', action='store', dest='server', default='127.0.0.1',
                         help='IP of the server where trex daemon server is running')
    parser.add_argument('--config', action='store', dest='config', default=None,
                         help='Path to local config file used to run TRex on local/remote')

    args = parser.parse_args()

    if args.run is None:
        print("Please specify start/stop/restart")
        sys.exit(1)

    if args.run == "start":
        start(args.server, args.config)
    elif args.run == "stop":
        stop(args.server)
    else:
        stop(args.server)
        start(args.server, args.config)
