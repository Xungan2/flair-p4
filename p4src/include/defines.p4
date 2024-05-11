#define FLAIR_PORT 23233

typedef bit<8> OP_t;
const OP_t OP_WRITE_REQUEST = 8w0;
const OP_t OP_READ_REQUEST = 8w1;
const OP_t OP_WRITE_REPLY = 8w2;
const OP_t OP_READ_REPLY = 8w3;

const OP_t OP_READ_RETRY = 8w4;

typedef bit<8> SESSION_ARRAY_LENGTH_t;
#define SESSION_ARRAY_LENGTH 256

typedef bit<12> KGROUP_ARRAY_LENGTH_t;
#define KGROUP_ARRAY_LENGTH 4096

#define RegRead(reg_name, act_name, value_size_t, array_length_t) \
    RegisterAction<value_size_t, array_length_t, value_size_t>(reg_name) act_name = { \
        void apply(inout value_size_t value, out value_size_t read_value) { \
            read_value = value; \
        } \
    }

#define RegRead_AndIncrease(reg_name, act_name, value_size_t, array_length_t) \
    RegisterAction<value_size_t, array_length_t, value_size_t>(reg_name) act_name = { \
        void apply(inout value_size_t value, out value_size_t read_value) { \
            read_value = value; \
            value = value + 1; \
        } \
    }

#define RegWrite(reg_name, act_name, value_size_t, array_length_t, new_value_name) \
    RegisterAction<value_size_t, array_length_t, value_size_t>(reg_name) act_name = { \
        void apply(inout value_size_t value) { \
            value = new_value_name; \
        } \
    }

#define NormalTable_WithoutParam(table_name, action_name) \
    table table_name { \
        actions = { \
            action_name; \
        } \
        const default_action = action_name(); \
        size = 1; \
    }

