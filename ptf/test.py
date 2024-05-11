import logging
import random
import socket
import struct

from p4testutils.misc_utils import *
from bfruntime_client_base_tests import BfRuntimeTest
import bfrt_grpc.client as gc

logger = get_logger()
swports = get_sw_ports()

leader_ip = '10.11.12.13'

# TODO:
port_dict = {
    '10.11.12.13': 3
}

class RegUtil():
    def __init__(self, reg_hdl, val_name_list, target):
        self.reg_hdl = reg_hdl
        self.val_name_list = val_name_list
        self.target = target
        
    def read(self, idx):
        resp = self.reg_hdl.entry_get(
                self.target,
                [self.reg_hdl.make_key([gc.KeyTuple('$REGISTER_INDEX', idx)])],
                {'from_hw': True}
            )
        data, _ = next(resp)
        data_dict = data.to_dict()
            
        val_list = []
        for name in self.val_name_list:
            val_list.append(data_dict[name][0])
            # val_list.append(data_dict[name])
        
        return val_list
    
    def write(self, idx, val_list):
        _val_list = []
        val_tuple_list = zip(self.val_name_list, val_list)
        for (name, val) in val_tuple_list:
            _val_list.append(gc.DataTuple(name, val))
        
        self.reg_hdl.entry_add(
            self.target,
            [self.reg_hdl.make_key([gc.KeyTuple('$REGISTER_INDEX', idx)])],
            [self.reg_hdl.make_data(_val_list)]
        )
        
class TableUtil():
    def __init__(self, table_hdl, key_name_list, act_param_dict, target):
        self.table_hdl = table_hdl
        self.key_name_list = key_name_list
        self.act_param_dict = act_param_dict
        self.target = target
        
    def entry_insert(self, key_list, act_name, param_list):
        _key_list = []
        key_tuple_list = zip(self.key_name_list, key_list)
        for key_name, key in key_tuple_list:
            _key_list.append(gc.KeyTuple(key_name, key))
        
        _val_list = []
        val_tuple_list = zip(self.act_param_dict[act_name], param_list)
        for val_name, val in val_tuple_list:
            _val_list.append(gc.DataTuple(val_name, val))
            
        self.table_hdl.entry_add(
            self.target,
            [self.table_hdl.make_key(_key_list)],
            [self.table_hdl.make_data(_val_list, act_name)]
        )

class InitTest(BfRuntimeTest):
    
    def setUp(self):
        client_id = 0
        p4_name = 'flair'
        BfRuntimeTest.setUp(self, client_id, p4_name)
        setup_random()
        
    def runTest(self):
        device_id = 0
        # TODO: pipeline
        pipe_id = 0xffff
        p4_name = 'flair'
        
        bfrt_info = self.interface.bfrt_info_get(p4_name)
        target = gc.Target(device_id=device_id, pipe_id=pipe_id)
        
        # Initialize session array
        reg_is_active = RegUtil(bfrt_info.table_get('Ingress.is_active'), ['Ingress.is_active.f1'], target)
        reg_session_id = RegUtil(bfrt_info.table_get('Ingress.session_id'), ['Ingress.session_id.f1'], target)
        reg_leader_ip = RegUtil(bfrt_info.table_get('Ingress.leader_ip'), ['Ingress.leader_ip.f1'], target)
        reg_session_seq_num = RegUtil(bfrt_info.table_get('Ingress.session_seq_num'), ['Ingress.session_seq_num.f1'], target)
        reg_heartbeat_tstamp = RegUtil(bfrt_info.table_get('Ingress.heartbeat_tstamp'), ['Ingress.heartbeat_tstamp.f1'], target)
        
        reg_is_active.write(0, [1])
        reg_session_id.write(0, [6])
        reg_leader_ip.write(0, [struct.unpack('!I', socket.inet_aton(leader_ip))[0]])
        # reg_session_seq_num.write(0, [0])
        # reg_heartbeat_tstamp.write(0, [0])
        # End
        
        # Initialize key group array
        reg_is_stable = RegUtil(bfrt_info.table_get('Ingress.is_stable'), ['Ingress.is_stable.f1'], target)
        reg_seq_num = RegUtil(bfrt_info.table_get('Ingress.seq_num'), ['Ingress.seq_num.f1'], target)
        reg_log_idx = RegUtil(bfrt_info.table_get('Ingress.log_idx'), ['Ingress.log_idx.f1'], target)
        reg_consistent_followers = RegUtil(bfrt_info.table_get('Ingress.consistent_followers'), ['Ingress.consistent_followers.f1'], target)
        # End
        
        # Table utils defination
        def table_entry_insert(table_hdl, act_name, key_tuple_list, val_tuple_list):
            _key_list = []
            for key_name, key in key_tuple_list:
                _key_list.append(gc.KeyTuple(key_name, key))
            
            _val_list = []
            for val_name, val in val_tuple_list:
                _val_list.append(gc.DataTuple(val_name, val))
                
            table_hdl.entry_add(
                target,
                [table_hdl.make_key(_key_list)],
                [table_hdl.make_data(_val_list, act_name)]
            )
        
        # End
        
        # Initialize table
        act_param_dict = {
            'Ingress.send': ['port'],
            'Ingress.drop': []
        }
        table_forward_packet = TableUtil(
            bfrt_info.table_get('Ingress.forward_packet'),
            ['hdr.ipv4.dst_addr'],
            act_param_dict,
            target
        )
        for ip, port_idx in zip(port_dict.keys(), port_dict.values()):
            ip_int = struct.unpack('!I', socket.inet_aton(ip))[0]
            table_forward_packet.entry_insert(
                [ip_int],
                'Ingress.send',
                [swports[port_idx]]
            )
        
        act_param_dict = {
            'Ingress.choose_consistent_follower_act': ['follower_idx']
        }
        table_choose_consistent_follower = TableUtil(
            bfrt_info.table_get('Ingress.choose_consistent_follower'),
            ['meta.kgroup_read_consistent_followers'],
            act_param_dict,
            target
        )
        for s in range(256):
            follower_list = []
            for i in range(8):
                if ((s>>i) & 1)  != 0:
                    follower_list.append(i)
            
            # TODO: 
            if len(follower_list) != 0:
                table_choose_consistent_follower.entry_insert(
                    [s],
                    'Ingress.choose_consistent_follower_act',
                    [follower_list[0]]
                )
        # End 
        