using VectorizationBase
using VectorizationBase: Mask, data, vifelse, tomask, vconvert
using Test

function diagnose_masks()
    println("--- STARTING ARM MASK DIAGNOSTICS (FIXED) ---")
    
    # 1. Determine Vector Width
    W_static = VectorizationBase.pick_vector_width(Float32)
    W = Int(W_static)
    println("Selected Vector Width W = $W for Float32")
    
    U_Type = VectorizationBase.mask_type(W_static)
    println("Mask Integer Type: $U_Type")

    # ---------------------------------------------------------
    # TEST 1: Integer -> Mask -> vifelse (Bit Order Check)
    # ---------------------------------------------------------
    println("\n[TEST 1] Integer -> Mask -> vifelse (Bit Order Check)")
    try
        # Create a single bit at position 0. 
        # On x86, this activates Lane 0.
        u_val = one(U_Type) 
        
        m = Mask{W}(u_val)
        
        # Vector with values 0, 1, 2, 3...
        # FIX: Added '...' to splat the tuple
        v_indices = Vec(ntuple(i -> Float32(i-1), Val(W))...)
        v_zeros = Vec(ntuple(_ -> 0.0f0, Val(W))...)
        
        # Select index if true, else 0
        res = vifelse(m, v_indices, v_zeros)
        
        res_tuple = Tuple(data(res))
        println("  Pattern (UInt): 0b$(string(u_val, base=2)) (Decimal: $u_val)")
        println("  Result Vec:     $res_tuple")
        
        # Check Lane 0
        if res_tuple[1] != 0.0f0 && all(x->x==0, res_tuple[2:end])
            println("  ✅ PASS: Bit 0 activated Lane 0.")
        elseif res_tuple[end] != 0.0f0 && all(x->x==0, res_tuple[1:end-1])
            println("  ❌ FAIL: Bit 0 activated Lane $(W-1) (REVERSED ORDER).")
        elseif all(x->x==0, res_tuple)
            println("  ❌ FAIL: Bit 0 activated NO lanes (Truncation/Shift issue).")
        else
             println("  ❌ FAIL: Bit 0 activated unexpected lane(s): $res_tuple")
        end
    catch e
        println("  ⚠️ CRASH: $e")
        Base.showerror(stdout, e, catch_backtrace())
    end

    # ---------------------------------------------------------
    # TEST 2: Vec{Bool} -> Mask
    # ---------------------------------------------------------
    println("\n[TEST 2] Vec{Bool} -> Mask (tomask Check)")

    # Create vector: [true, false, false, ...]
    # FIX: Added '...' to splat the tuple
    bool_tuple = ntuple(i -> i==1, Val(W))
    v_bool = Vec(bool_tuple...)
    
    # Convert to mask
    m_from_bool = tomask(v_bool)
    u_internal = data(m_from_bool)
    
    println("  Input Vec:      $bool_tuple")
    println("  Result UInt:    0b$(string(u_internal, base=2)) (Decimal: $u_internal)")
    
    if u_internal == 1
        println("  ✅ PASS: Lane 0 mapped to Bit 0.")
    elseif u_internal == (1 << (W-1))
        println("  ❌ FAIL: Lane 0 mapped to Bit $(W-1) (REVERSED ORDER).")
    elseif u_internal == 0