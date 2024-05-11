parser TofinoIngressParser (
    packet_in pkt,
    out ingress_intrinsic_metadata_t ig_intr_md)
{
    state start {
        pkt.extract (ig_intr_md);
        transition select (ig_intr_md.resubmit_flag) {
            1 : parser_resubmit;
            0 : parser_port_metadata;
        }
    }

    state parser_resubmit {
        transition reject;
    }

    state parser_port_metadata {
        pkt.advance (PORT_METADATA_SIZE);
        transition accept;
    }
}

struct ingress_headers_t {
    ethernet_h ethernet;
    ipv4_h ipv4;
    tcp_h tcp;
    // udp_h udp;
    message_h message;
    flair_h flair;
}

struct ingress_metadata_t {
    /* Packer information */
    ipv4_addr_t src_addr;
    bit<16> src_port;
    ipv4_addr_t dst_addr;
    bit<16> dst_port;

    bit<1> is_flair;

    bit<32> choose_consistent_follower_ip;

    /* Session array information */
    SESSION_ARRAY_LENGTH_t sessionArray_idx;
    bit<64> cur_seq_num;
    bit<1> sessionArray_read_is_active;
    bit<32> sessionArray_read_session_id;
    bit<32> sessionArray_read_leader_ip;

    /* Key group array information */
    KGROUP_ARRAY_LENGTH_t kgroup_idx;
    bit<1> kgroup_read_is_stable;
    bit<64> kgroup_read_seq_num;
    bit<64> kgroup_read_log_idx;
    bit<8> kgroup_read_consistent_followers;

    bit<64> kgroup_new_log_idx;
    bit<8> kgroup_new_consistent_followers;
}

parser IngressParser (
    packet_in pkt,
    out ingress_headers_t hdr,
    out ingress_metadata_t meta,
    out ingress_intrinsic_metadata_t ig_intr_md)
{
    TofinoIngressParser() tofino_parser;

    state start {
        tofino_parser.apply (pkt, ig_intr_md);
        transition parser_ethernet;
    }

    state parser_ethernet {
        pkt.extract (hdr.ethernet);
        transition select (hdr.ethernet.ether_type) {
            ETHERTYPE_IPV4 : parser_ipv4;
            default : reject;
        }
    }

    state parser_ipv4 {
        pkt.extract (hdr.ipv4);
        meta.src_addr = hdr.ipv4.src_addr;
        meta.dst_addr = hdr.ipv4.dst_addr;
        transition select (hdr.ipv4.protocol) {
            IP_PROTOCOLS_TCP : parser_tcp;
            // IP_PROTOCOLS_UDP : parser_udp;
            default : reject;
        }
    }

    state parser_tcp {
        pkt.extract (hdr.tcp);
        transition parser_message;
    }

    // state parser_udp {
    //     pkt.extract (hdr.udp);
    //     meta.src_port = hdr.udp.src_port;
    //     meta.dst_port = hdr.udp.dst_port;
    //     meta.is_flair = 1w0;
    //     transition select (hdr.udp.src_port, hdr.udp.dst_port) {
    //         (FLAIR_PORT, _) : parser_flair;
    //         (_, FLAIR_PORT) : parser_flair;
    //         default : accept;
    //     }
    // }

    state parser_message {
        pkt.extract (hdr.message);
        meta.is_flair = 1w0;
        transition select (hdr.message.is_flair) {
            8w1 : parser_flair;
            default : accept;
        }
    }

    state parser_flair {
        pkt.extract (hdr.flair);
        meta.is_flair = 1w1;
        transition accept;
    }
}

control IngressDeparser (
    packet_out pkt,
    inout ingress_headers_t hdr,
    in ingress_metadata_t meta,
    in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md)
{
    apply {
        pkt.emit(hdr);
    }
}

struct egress_headers_t {
    ethernet_h ethernet;
    ipv4_h ipv4;
    udp_h udp;
    flair_h flair;
}

struct egress_metadata_t {
    ipv4_addr_t src_addr;
    bit<16> src_port;
    ipv4_addr_t dst_addr;
    bit<16> dst_port;
    bit<4> version;
}

parser EgressParser (
    packet_in pkt,
    out egress_headers_t hdr,
    out egress_metadata_t meta,
    out egress_intrinsic_metadata_t eg_intr_md)
{
    state start {
        pkt.extract(eg_intr_md);
        transition accept;
    }
}

control EgressDeparser (
    packet_out pkt,
    inout egress_headers_t hdr,
    in egress_metadata_t meta,
    in egress_intrinsic_metadata_for_deparser_t eg_dprsr_md)
{
    apply {
    }
}