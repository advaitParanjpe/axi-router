class axis_router_transaction extends uvm_sequence_item;
  rand int unsigned tr_id;
  rand int unsigned ingress;
  rand int unsigned dest;
  rand int unsigned length;
  rand bit malformed;
  rand bit invalid_dest;
  rand bit oversize;
  rand int unsigned inter_beat_gap[$];
  rand bit [31:0] payload[$];

  constraint c_basic {
    ingress < 2;
    length inside {[1:8]};
    payload.size() == length;
    inter_beat_gap.size() == length;
    foreach (inter_beat_gap[i]) inter_beat_gap[i] <= 3;
    if (!invalid_dest) dest < 4;
    if (invalid_dest) dest > 3;
  }

  `uvm_object_utils_begin(axis_router_transaction)
    `uvm_field_int(tr_id, UVM_DEFAULT)
    `uvm_field_int(ingress, UVM_DEFAULT)
    `uvm_field_int(dest, UVM_DEFAULT)
    `uvm_field_int(length, UVM_DEFAULT)
    `uvm_field_int(malformed, UVM_DEFAULT)
    `uvm_field_int(invalid_dest, UVM_DEFAULT)
    `uvm_field_int(oversize, UVM_DEFAULT)
    `uvm_field_queue_int(inter_beat_gap, UVM_DEFAULT)
    `uvm_field_queue_int(payload, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "axis_router_transaction");
    super.new(name);
  endfunction

  function bit is_drop();
    return invalid_dest || malformed || oversize;
  endfunction

  function int unsigned expected_output();
    return dest[1:0];
  endfunction

  function string convert2string();
    return $sformatf("id=%0d ingress=%0d dest=%0d len=%0d invalid=%0b malformed=%0b oversize=%0b",
                     tr_id, ingress, dest, length, invalid_dest, malformed, oversize);
  endfunction
endclass
