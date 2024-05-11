#include <core.p4>
#include <tna.p4>

#include "include/defines.p4"
#include "include/header.p4"
#include "include/parser.p4"

control Ingress (
    inout ingress_headers_t hdr,
    inout ingress_metadata_t meta,
    in ingress_intrinsic_metadata_t ig_intr_md,
    in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t ig_tm_md)
{
    /* Forwarding table defination*/
    action send (PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
    }
    action drop () {
        ig_dprsr_md.drop_ctl = 1;
    }
    table forward_packet {
        key = {
            hdr.ipv4.dst_addr : exact; // TODO:  
        }

        actions = {
            send;
            drop;
        }

        const default_action = drop();
        size = 4096;
    }
    /* End */

    /* Session array defination */
    Register<bit<1>, SESSION_ARRAY_LENGTH_t>(SESSION_ARRAY_LENGTH, 0) is_active;
    Register<bit<32>, SESSION_ARRAY_LENGTH_t>(SESSION_ARRAY_LENGTH, 0) session_id;
    Register<bit<32>, SESSION_ARRAY_LENGTH_t>(SESSION_ARRAY_LENGTH, 0) leader_ip;
    Register<bit<32>, SESSION_ARRAY_LENGTH_t>(SESSION_ARRAY_LENGTH, 0) session_seq_num_lo;
    Register<bit<32>, SESSION_ARRAY_LENGTH_t>(SESSION_ARRAY_LENGTH, 0) session_seq_num_hi;
    Register<bit<48>, SESSION_ARRAY_LENGTH_t>(SESSION_ARRAY_LENGTH, 0) heartbeat_tstamp;

    RegRead(is_active, read_is_active, bit<1>, SESSION_ARRAY_LENGTH_t);
    RegRead(session_id, read_session_id, bit<32>, SESSION_ARRAY_LENGTH_t);
    RegRead(leader_ip, read_leader_ip, bit<32>, SESSION_ARRAY_LENGTH_t);

    RegRead_AndIncrease(session_seq_num_lo, increase_session_seq_num_lo, bit<32>, SESSION_ARRAY_LENGTH_t);
    RegRead(session_seq_num_hi, read_session_seq_num_hi, bit<32>, SESSION_ARRAY_LENGTH_t);
    RegRead_AndIncrease(session_seq_num_hi, increase_session_seq_num_hi, bit<32>, SESSION_ARRAY_LENGTH_t);
    /* End */

    /* Session table defination */
    action verify_session_active_act() {
        meta.sessionArray_read_is_active = read_is_active.execute(meta.sessionArray_idx);
    }
    NormalTable_WithoutParam(verify_session_active, verify_session_active_act)

    action tb_get_leader_ip_act() {
        meta.sessionArray_read_leader_ip = read_leader_ip.execute(meta.sessionArray_idx);
    }
    NormalTable_WithoutParam(tb_get_leader_ip, tb_get_leader_ip_act)

    action tb_get_session_id_act() {
        meta.sessionArray_read_session_id = read_session_id.execute(meta.sessionArray_idx);
    }
    NormalTable_WithoutParam(tb_get_session_id, tb_get_session_id_act)

    action tb_increase_session_seq_num_lo_act() {
        meta.cur_seq_num[31:0] = increase_session_seq_num_lo.execute(meta.sessionArray_idx);
    }
    NormalTable_WithoutParam(tb_increase_session_seq_num_lo, tb_increase_session_seq_num_lo_act)
    action tb_read_session_seq_num_hi_act() {
        meta.cur_seq_num[63:32] = read_session_seq_num_hi.execute(meta.sessionArray_idx);
    }
    NormalTable_WithoutParam(tb_read_session_seq_num_hi, tb_read_session_seq_num_hi_act)
    action tb_increase_session_seq_num_hi_act() {
        meta.cur_seq_num[63:32] = increase_session_seq_num_hi.execute(meta.sessionArray_idx);
    }
    NormalTable_WithoutParam(tb_increase_session_seq_num_hi, tb_increase_session_seq_num_hi_act)
    /* End */

    /* Key group array defination */
    Register<bit<1>, KGROUP_ARRAY_LENGTH_t>(KGROUP_ARRAY_LENGTH, 0) is_stable;
    Register<bit<32>, KGROUP_ARRAY_LENGTH_t>(KGROUP_ARRAY_LENGTH, 0) seq_num_lo;
    Register<bit<32>, KGROUP_ARRAY_LENGTH_t>(KGROUP_ARRAY_LENGTH, 0) seq_num_hi;
    Register<bit<32>, KGROUP_ARRAY_LENGTH_t>(KGROUP_ARRAY_LENGTH, 0) log_idx_lo;
    Register<bit<32>, KGROUP_ARRAY_LENGTH_t>(KGROUP_ARRAY_LENGTH, 0) log_idx_hi;
    Register<bit<8>, KGROUP_ARRAY_LENGTH_t>(KGROUP_ARRAY_LENGTH, 0) consistent_followers;

    RegRead(is_stable, read_is_stable, bit<1>, KGROUP_ARRAY_LENGTH_t);
    RegRead(seq_num_lo, read_seq_num_lo, bit<32>, KGROUP_ARRAY_LENGTH_t);
    RegRead(seq_num_hi, read_seq_num_hi, bit<32>, KGROUP_ARRAY_LENGTH_t);
    RegWrite(seq_num_lo, write_seq_num_lo, bit<32>, KGROUP_ARRAY_LENGTH_t, meta.cur_seq_num[31:0]);
    RegWrite(seq_num_hi, write_seq_num_hi, bit<32>, KGROUP_ARRAY_LENGTH_t, meta.cur_seq_num[63:32]);
    RegRead(log_idx_lo, read_log_idx_lo, bit<32>, KGROUP_ARRAY_LENGTH_t);
    RegRead(log_idx_hi, read_log_idx_hi, bit<32>, KGROUP_ARRAY_LENGTH_t);
    RegWrite(log_idx_lo, write_log_idx_lo, bit<32>, KGROUP_ARRAY_LENGTH_t, meta.kgroup_new_log_idx[31:0]);
    RegWrite(log_idx_hi, write_log_idx_hi, bit<32>, KGROUP_ARRAY_LENGTH_t, meta.kgroup_new_log_idx[63:32]);
    RegRead(consistent_followers, read_consistent_followers, bit<8>, KGROUP_ARRAY_LENGTH_t);
    RegWrite(consistent_followers, write_consistent_followers, bit<8>, KGROUP_ARRAY_LENGTH_t, meta.kgroup_new_consistent_followers);

    RegisterAction<bit<1>, KGROUP_ARRAY_LENGTH_t, bit<1>>(is_stable) reg_set_stable = {
        void apply(inout bit<1> value) {
            value = 1w1;
        }
    };
    RegisterAction<bit<1>, KGROUP_ARRAY_LENGTH_t, bit<1>>(is_stable) reg_set_unstable = {
        void apply(inout bit<1> value) {
            value = 1w0;
        }
    };
    /* End */

    /* Key group table defination */
    action calc_kgroup_idx_act() {
        meta.kgroup_idx = hdr.flair.key[11:0]; // TODO:
    }
    NormalTable_WithoutParam(calc_kgroup_idx, calc_kgroup_idx_act)

    action tb_get_stable_act() {
        meta.kgroup_read_is_stable = read_is_stable.execute(meta.kgroup_idx);
    }
    NormalTable_WithoutParam(tb_get_stable, tb_get_stable_act)
    action tb_set_stable_act() {
        reg_set_stable.execute(meta.kgroup_idx);
    }
    NormalTable_WithoutParam(tb_set_stable, tb_set_stable_act)
    action tb_set_unstable_act() {
        reg_set_unstable.execute(meta.kgroup_idx);
    }
    NormalTable_WithoutParam(tb_set_unstable, tb_set_unstable_act)

    action tb_get_seq_num_lo_act() {
        meta.kgroup_read_seq_num[31:0] = read_seq_num_lo.execute(meta.kgroup_idx);
    }
    NormalTable_WithoutParam(tb_get_seq_num_lo, tb_get_seq_num_lo_act)
    action tb_get_seq_num_hi_act() {
        meta.kgroup_read_seq_num[63:32] = read_seq_num_hi.execute(meta.kgroup_idx);
    }
    NormalTable_WithoutParam(tb_get_seq_num_hi, tb_get_seq_num_hi_act)
    action tb_write_seq_num_lo_act() {
        write_seq_num_lo.execute(meta.kgroup_idx);
    }
    NormalTable_WithoutParam(tb_write_seq_num_lo, tb_write_seq_num_lo_act)
    action tb_write_seq_num_hi_act() {
        write_seq_num_hi.execute(meta.kgroup_idx);
    }
    NormalTable_WithoutParam(tb_write_seq_num_hi, tb_write_seq_num_hi_act)
    action tb_get_log_idx_lo_act() {
        meta.kgroup_read_log_idx[31:0] = read_log_idx_lo.execute(meta.kgroup_idx);
    }
    NormalTable_WithoutParam(tb_get_log_idx_lo, tb_get_log_idx_lo_act)
    action tb_get_log_idx_hi_act() {
        meta.kgroup_read_log_idx[63:32] = read_log_idx_hi.execute(meta.kgroup_idx);
    }
    NormalTable_WithoutParam(tb_get_log_idx_hi, tb_get_log_idx_hi_act)
    action tb_write_log_idx_lo_act() {
        meta.kgroup_new_log_idx[31:0] = hdr.flair.log_idx[31:0];
        write_log_idx_lo.execute(meta.kgroup_idx);
    }
    NormalTable_WithoutParam(tb_write_log_idx_lo, tb_write_log_idx_lo_act)
    action tb_write_log_idx_hi_act() {
        meta.kgroup_new_log_idx[63:32] = hdr.flair.log_idx[63:32];
        write_log_idx_hi.execute(meta.kgroup_idx);
    }
    NormalTable_WithoutParam(tb_write_log_idx_hi, tb_write_log_idx_hi_act)

    action tb_get_consistent_followers_act() {
        meta.kgroup_read_consistent_followers = read_consistent_followers.execute(meta.kgroup_idx);
    }
    NormalTable_WithoutParam(tb_get_consistent_followers, tb_get_consistent_followers_act)
    action tb_write_consistent_followers_act() {
        meta.kgroup_new_consistent_followers = hdr.flair.cflwrs;
        write_consistent_followers.execute(meta.kgroup_idx);
    }
    NormalTable_WithoutParam(tb_write_consistent_followers, tb_write_consistent_followers_act)
    /* End */

    /* Consistent follower bitmap util defination */
    Register<bit<32>, bit<8>>(8, 0) follower_ip;
    RegRead(follower_ip, read_follower_ip, bit<32>, bit<8>);

    // TODO: use more efficient method
    action choose_consistent_follower_act(bit<8> follower_idx) {
        meta.choose_consistent_follower_ip = read_follower_ip.execute(follower_idx);
    }
    table choose_consistent_follower {
        key = {
            meta.kgroup_read_consistent_followers: exact;
        }

        actions = {
            choose_consistent_follower_act;
        }

        size = 256;
    }
    /* End */

    // TODO: heartbeat packet
    // TODO: checksum
    apply {
        meta.sessionArray_idx = 0;
        
        verify_session_active.apply();

        tb_get_session_id.apply();
        tb_get_leader_ip.apply();

        calc_kgroup_idx.apply();
        
        if (meta.sessionArray_read_is_active == 1w1) {
            // Write request
            if (hdr.flair.op == OP_WRITE_REQUEST) {
                tb_write_seq_num_lo.apply();
                tb_write_seq_num_hi.apply();
                
                tb_set_unstable.apply();

                // Get the seq num
                tb_increase_session_seq_num_lo.apply();
                if (meta.cur_seq_num[31:0] == 32w0xffffffff)
                    tb_increase_session_seq_num_hi.apply();
                else
                    tb_read_session_seq_num_hi.apply();

                hdr.flair.seq = meta.cur_seq_num;
                hdr.flair.sid = meta.sessionArray_read_session_id;
                hdr.ipv4.dst_addr = meta.sessionArray_read_leader_ip;
                
                forward_packet.apply();
            }
            else {
                tb_get_seq_num_lo.apply();
                tb_get_seq_num_hi.apply();

                // Read request
                if (hdr.flair.op == OP_READ_REQUEST) {
                    tb_get_log_idx_lo.apply();
                    tb_get_log_idx_hi.apply();
                    tb_get_consistent_followers.apply();

                    tb_get_stable.apply();
                    if (meta.kgroup_read_is_stable == 1w1) {
                        // Choose a replica from the consistent follower bitmap
                        choose_consistent_follower.apply();

                        hdr.flair.sid = meta.sessionArray_read_session_id;
                        hdr.flair.seq = meta.kgroup_read_seq_num;
                        hdr.flair.log_idx = meta.kgroup_read_log_idx;

                        hdr.ipv4.dst_addr = meta.choose_consistent_follower_ip;
                    }
                    else {
                        hdr.ipv4.dst_addr = meta.sessionArray_read_leader_ip;
                    }

                    forward_packet.apply();
                }
                else {
                    // Verify session id
                    if (hdr.flair.sid == meta.sessionArray_read_session_id) {
                        // Write reply
                        if (hdr.flair.op == OP_WRITE_REPLY) {
                            if (hdr.flair.seq[31:0] == meta.kgroup_read_seq_num[31:0]) {
                                if (hdr.flair.seq[63:32] == meta.kgroup_read_seq_num[63:32]) {
                                    tb_write_log_idx_lo.apply();
                                    tb_write_log_idx_hi.apply();
                                    tb_write_consistent_followers.apply();

                                    tb_set_stable.apply();
                                }
                            }

                            forward_packet.apply();
                        }
                        // Read reply
                        else if (hdr.flair.op == OP_READ_REPLY) {
                            if (hdr.flair.from_leader == 8w0 && hdr.flair.seq[31:0] == meta.kgroup_read_seq_num[31:0]) {
                                if (hdr.flair.seq[63:32] == meta.kgroup_read_seq_num[63:32]) {
                                    // Generate new read request
                                    hdr.flair.op = OP_READ_RETRY; // TODO:
                                }
                            }

                            forward_packet.apply();
                        }
                        else ig_dprsr_md.drop_ctl = 1;
                    }
                    else ig_dprsr_md.drop_ctl = 1;
                }
            }
        }
        else ig_dprsr_md.drop_ctl = 1;

        ig_tm_md.bypass_egress = 1;
    }
}

control Egress (
    inout egress_headers_t hdr,
    inout egress_metadata_t meta,
    in egress_intrinsic_metadata_t eg_intr_md,
    in egress_intrinsic_metadata_from_parser_t eg_prsr_md,
    inout egress_intrinsic_metadata_for_deparser_t eg_dprsr_md,
    inout egress_intrinsic_metadata_for_output_port_t eg_oport_md)
{
    apply {
    }
}

Pipeline (
    IngressParser(), Ingress(), IngressDeparser(),
    EgressParser(), Egress(), EgressDeparser()
) pipe;
Switch(pipe) main;