/*
 * Testcase for 2D convolution using the vector ALU.
 * 
 * Author: Andreas Bytyn (bytyn@ice.rwth-aachen.de)
*/

#ifndef __chess__
#include <cstring>
#include <cstdlib>
#include <iostream>
#include <fstream>
#include <math.h>

using namespace std;
#endif

// Some config stuff
//#define FNAME_DATA "data/input.dat"

// Verification or performace mode?
//#define VERIFICATION_MODE_ON

// Turn debug output on/off
//#define DEBUG_OUTPUT

#include "memory/scratchpad_init.h"
#include "utils/helper_functions.h"
#include "utils/comp_stats.h"
//#include "kernels/conv2d_layer_no_dma_interleave.h"
#include "kernels/conv2d_layer.h"
//#include "kernels/conv2d_layer_no_stride.h"

// Fixed-Point and Precision-Gating config
#define FULL_MASK_INT16 0xFFFF
#define FULL_MASK_INT8  0xFF
#define FULL_MASK_INT4  0xF
#define PRECISION (INTBITS_INP + FRACBITS_INP - GATEBITS_INP)
#define BACKSHIFT FRACBITS_WGT

#ifndef ZGUARDING_FLAG
#define ZGUARDING_FLAG 1
#endif

// Global pointers to data in DDR (DM_Glob) memory
short chess_storage(DM_Glob)* pFilters_DDR;
short chess_storage(DM_Glob)* pFiltersDW_DDR;
short chess_storage(DM_Glob)* pBiases_DDR;
short chess_storage(DM_Glob)* pBiasesDW_DDR;
short chess_storage(DM_Glob)* pIFMaps_DDR;
short chess_storage(DM_Glob)* pResidual_DDR;
short chess_storage(DM_Glob)* pOFMaps_Conv_DDR;
short chess_storage(DM_Glob)* pOFMaps_Pool_DDR;
short* pOFMaps_Expected;

#ifndef __chess__
int readmem_from_dat(std::fstream& instream, short chess_storage(DM_Glob)* pMem, unsigned len)
{
    string tmp;
    short readval;
    
    for(int k=0; k<len; k++) {
        // Check for End-of-file and report error in case the expected number of
        // words to read (as inidicated by len) does not match
        // the actual number of words present in the file
        if(instream.eof()) {
            cerr << "ERROR: Reached end of file (input.dat file) before all words were read." << endl;
            return 1;
        }
        instream >> tmp;
        readval = std::stoi(tmp, nullptr, 0);
        pMem[k] = readval;
    }
    
    return 0;
}
#endif

int main()
{
#ifndef __chess__
    scratchpad_mem_init();
    
    int len_ofmaps = POOL_FUNC == nopool ? LENGTH_OFMAPS_CONV : LENGTH_OFMAPS_POOL;
    
    // Initialize DDR-pointers with data from file
    pFilters_DDR      = (short chess_storage(DM_Glob)*)std::malloc(LENGTH_FILTERS * sizeof(short));
    pFiltersDW_DDR    = (short chess_storage(DM_Glob)*)std::malloc(LENGTH_FILTERS_DW * sizeof(short));
    pBiases_DDR       = (short chess_storage(DM_Glob)*)std::malloc(LENGTH_BIASES * sizeof(short));
    pBiasesDW_DDR     = (short chess_storage(DM_Glob)*)std::malloc(LENGTH_BIASES_DW * sizeof(short));
    pIFMaps_DDR       = (short chess_storage(DM_Glob)*)std::malloc(LENGTH_IFMAPS * sizeof(short));
    pResidual_DDR     = (short chess_storage(DM_Glob)*)std::malloc(LENGTH_RESIDUAL * sizeof(short));
    pOFMaps_Conv_DDR  = (short chess_storage(DM_Glob)*)std::malloc(LENGTH_OFMAPS_CONV * sizeof(short));
    pOFMaps_Pool_DDR  = (short chess_storage(DM_Glob)*)std::malloc(LENGTH_OFMAPS_POOL * sizeof(short));
    pOFMaps_Expected  = (short*)std::malloc(len_ofmaps * sizeof(short));
    
    // Set all OFMaps to 0 to avoid differences between native (Host) and ISS execution
    std::memset((void*)pOFMaps_Conv_DDR, 0, LENGTH_OFMAPS_CONV * sizeof(short));
    std::memset((void*)pOFMaps_Pool_DDR, 0, LENGTH_OFMAPS_POOL * sizeof(short));
    
    // Load data for different pointers from input file
    std::fstream f_data(FNAME_DATA, std::ios_base::in);
    short readval;

    if(!f_data.is_open()) {
        std::cout << "[Error] Could not open input file: " << FNAME_DATA << std::endl;
        return 1;
    }
    
    if(readmem_from_dat(f_data, pFiltersDW_DDR, LENGTH_FILTERS_DW) != 0) return 1;
    if(readmem_from_dat(f_data, pFilters_DDR, LENGTH_FILTERS) != 0)      return 1;
    
    if(readmem_from_dat(f_data, pBiasesDW_DDR, LENGTH_BIASES_DW) != 0) return 1;
    if(readmem_from_dat(f_data, pBiases_DDR, LENGTH_BIASES) != 0)      return 1;
    
    if(readmem_from_dat(f_data, pIFMaps_DDR, LENGTH_IFMAPS) != 0)     return 1;
    if(readmem_from_dat(f_data, pResidual_DDR, LENGTH_RESIDUAL) != 0) return 1;
    if(readmem_from_dat(f_data, pOFMaps_Expected, len_ofmaps) != 0)   return 1;
#else
    pFilters_DDR     = (short chess_storage(DM_Glob)*)ADDR_FILTERS;
    pFiltersDW_DDR   = (short chess_storage(DM_Glob)*)ADDR_FILTERS_DW;
    pBiases_DDR      = (short chess_storage(DM_Glob)*)ADDR_BIASES;
    pBiasesDW_DDR    = (short chess_storage(DM_Glob)*)ADDR_BIASES_DW;
    pIFMaps_DDR      = (short chess_storage(DM_Glob)*)ADDR_IFMAPS;
    pResidual_DDR    = (short chess_storage(DM_Glob)*)ADDR_RESIDUAL;
    pOFMaps_Conv_DDR = (short chess_storage(DM_Glob)*)ADDR_OFMAPS_CONV;
    pOFMaps_Pool_DDR = (short chess_storage(DM_Glob)*)ADDR_OFMAPS_POOL;
#endif
    
    chess_profile_begin();
    
    // Setup arithmetic
    set_round_mode(RND_TRUNCATE | RND_SATURATE);
    set_backshift(BACKSHIFT);
    set_int_mode(INTMODE);
    set_zguard_flag(ZGUARDING_FLAG);
    
    
    if(INTMODE == INT16_MODE) {
        unsigned mask = (FULL_MASK_INT16 << (16-PRECISION)) & FULL_MASK_INT16;
        set_precision_mask(mask);
    } else if(INTMODE == INT8_MODE) {
        unsigned subw_mask = (FULL_MASK_INT8 << (8-PRECISION)) & FULL_MASK_INT8;
        unsigned mask = (subw_mask << 8) | subw_mask;
        set_precision_mask(mask);
    } else if(INTMODE == INT4_MODE) {
        unsigned subw_mask = (FULL_MASK_INT4 << (4-PRECISION)) & FULL_MASK_INT4;
        unsigned mask = (subw_mask << 12) | (subw_mask << 8) | (subw_mask << 4) | subw_mask;
        set_precision_mask(mask);
    }
#ifndef __chess__
    else {
        cerr << "ERROR: INTMODE = " << INTMODE << " is not a valid integer mode!" << endl;
        return 1;
    }
#endif
    
    // Setup config for convolution
    conv2d_config_t conv_cfg;
    
    // DDR adresses
    conv_cfg.pIFMaps_DDR      = pIFMaps_DDR;
    conv_cfg.pFilters_DDR     = pFilters_DDR;
    conv_cfg.pFiltersDW_DDR   = pFiltersDW_DDR;
    conv_cfg.pBiases_DDR      = pBiases_DDR;
    conv_cfg.pBiasesDW_DDR    = pBiasesDW_DDR;
    conv_cfg.pResidual_DDR    = pResidual_DDR;
    conv_cfg.pOFMaps_Conv_DDR = pOFMaps_Conv_DDR;
    conv_cfg.pOFMaps_Pool_DDR = pOFMaps_Pool_DDR;
    
    // Arithmetic config
    conv_cfg.intmode          = INTMODE;
    conv_cfg.subw_parallelism = 1 << INTMODE;
    conv_cfg.ifmap_intbits    = INTBITS_INP;
    conv_cfg.ifmap_fracbits   = FRACBITS_INP;
    conv_cfg.filter_intbits   = INTBITS_WGT;
    conv_cfg.filter_fracbits  = FRACBITS_WGT;
    
    // Conv setup
    conv_cfg.type                  = CONV_TYPE;
    conv_cfg.fheight               = FILTER_HEIGHT;
    conv_cfg.fwidth                = FILTER_WIDTH;
    conv_cfg.och_cnt               = NR_FILTERS;
    conv_cfg.stride                = CONV_STRIDE;
    conv_cfg.dilation              = CONV_DILATION;
    conv_cfg.ifmap_height          = IFMAP_HEIGHT;
    conv_cfg.ifmap_width           = IFMAP_WIDTH;
    conv_cfg.ich_cnt               = IFMAP_DIM_CH;
    conv_cfg.ifmap_is_xpadded      = IFMAP_IS_XPADDED;
    conv_cfg.ifmap_pad_left        = IFMAP_PAD_LEFT;
    conv_cfg.ifmap_pad_right       = IFMAP_PAD_RIGHT;
    conv_cfg.ifmap_pad_top         = IFMAP_PAD_TOP;
    conv_cfg.ifmap_pad_bottom      = IFMAP_PAD_BOTTOM;
    conv_cfg.conv_ofmap_height     = CONV_OFMAP_HEIGHT;
    conv_cfg.conv_ofmap_width      = CONV_OFMAP_WIDTH;
    conv_cfg.conv_ofmap_xpad       = CONV_OFMAP_APPLY_XPAD;
    conv_cfg.conv_ofmap_pad_left   = CONV_OFMAP_PAD_LEFT;
    conv_cfg.conv_ofmap_pad_right  = CONV_OFMAP_PAD_RIGHT;
    conv_cfg.conv_ofmap_pad_top    = CONV_OFMAP_PAD_TOP;
    conv_cfg.conv_ofmap_pad_bottom = CONV_OFMAP_PAD_BOTTOM;
    conv_cfg.activation            = ACT_FUNC;
    
    // Conv tile config
    conv_cfg.tile_tof = FILTERS_PARALLEL;
    conv_cfg.tile_tix = IFMAP_XSLICE_WIDTH;
    conv_cfg.tile_tif = IFMAPS_PARALLEL;
    
    // Pool config
    conv_cfg.pooling               = POOL_FUNC;
    conv_cfg.pool_before_wb        = POOL_FUNC != nopool ? true : false;
    conv_cfg.pool_kernel_size      = POOL_KERNEL_SIZE;
    conv_cfg.pool_stride           = POOL_FUNC == nopool ? 1 : POOL_STRIDE;
    conv_cfg.pool_ifmap_pad_left   = POOL_IFMAP_PAD_LEFT;
    conv_cfg.pool_ifmap_pad_right  = POOL_IFMAP_PAD_RIGHT;
    conv_cfg.pool_ifmap_pad_top    = POOL_IFMAP_PAD_TOP;
    conv_cfg.pool_ifmap_pad_bottom = POOL_IFMAP_PAD_BOTTOM;
    conv_cfg.pool_ofmap_height     = POOL_OFMAP_HEIGHT;
    conv_cfg.pool_ofmap_width      = POOL_OFMAP_WIDTH;
    conv_cfg.pool_ofmap_xpad       = POOL_OFMAP_APPLY_XPAD;
    conv_cfg.pool_ofmap_pad_left   = POOL_OFMAP_PAD_LEFT;
    conv_cfg.pool_ofmap_pad_right  = POOL_OFMAP_PAD_RIGHT;
    conv_cfg.pool_ofmap_pad_top    = POOL_OFMAP_PAD_TOP;
    conv_cfg.pool_ofmap_pad_bottom = POOL_OFMAP_PAD_BOTTOM;
    
    int errstate = conv2d_layer(conv_cfg);
    chess_profile_end();
    
    if(errstate) return errstate;
    
    
#if defined(VERIFICATION_MODE_ON) || !defined(__chess__)
    // Verify result after convolution and pooling
    ushort verify_ofmap_height, verify_ofmap_width;
    
    if(conv_cfg.pooling != nopool) {
        verify_ofmap_height = conv_cfg.pool_ofmap_height;
        verify_ofmap_width  = conv_cfg.wbbuffer_lwidth;
    } else {
        verify_ofmap_height = conv_cfg.conv_ofmap_height;
        verify_ofmap_width  = conv_cfg.ofmap_buffer_lwidth;
    }
    
    short chess_storage(DM_Glob)* pOFMaps_DDR = POOL_FUNC != nopool ? pOFMaps_Pool_DDR : pOFMaps_Conv_DDR;
#endif
    
#if defined(__chess__)
    // Wait for DMA to finish and stop simulation so the cycle-count can be written
    wait_for_dma();
    chess_stop();
#endif
    
#if !defined(__chess__)
    statTracker.report_stats();
#endif
    
    // Verify OFMaps between different levels (Native, ISS, RTL)
#ifdef VERIFICATION_MODE_ON
    for(ushort y=0; y < verify_ofmap_height; y++) {
        for(ushort ofmap_nr=0; ofmap_nr < conv_cfg.och_cnt_subw; ofmap_nr++) {
            for(ushort x=0; x < verify_ofmap_width; x++) {
                short ofmapVal = *(pOFMaps_DDR + y * conv_cfg.och_cnt_subw * verify_ofmap_width + ofmap_nr * verify_ofmap_width + x);
                chess_report(ofmapVal);
            }
        }
    }
#endif

    // Compare OFMaps with expected results from golden reference
#ifndef __chess__
    printf("\nComparing results from native run with expected results...");

    float fixpToFPFactor = pow(2, FRACBITS_INP);
    bool mismatch = false;
    
    for(int ofmap_nr=0; ofmap_nr < conv_cfg.och_cnt_subw; ofmap_nr++) {
        printf("\n\n# OFMap %d:\n", ofmap_nr);
        for(int y=0; y < verify_ofmap_height; y++) {
            for(int x=0; x < verify_ofmap_width; x++) {
                int idx_nat = y * (verify_ofmap_width * conv_cfg.och_cnt_subw) + ofmap_nr * verify_ofmap_width + x;
                int idx_ref = y * (verify_ofmap_width * conv_cfg.och_cnt_subw) + ofmap_nr * verify_ofmap_width + x;
                short res_ref    = pOFMaps_Expected[idx_ref];
                short res_native = pOFMaps_DDR[idx_nat];
                if(res_native != res_ref) {
                    printf("[x=%d,y=%d]: \t%x [%.4f] \t(Nat) vs. \t%x [%.4f] (Ref)\n", x, y, (res_native & 0xFFFF), (float)(res_native / fixpToFPFactor), (res_ref & 0xFFFF), (float)(res_ref / fixpToFPFactor));
                    mismatch = true;
                }
            }
        }
    }

    if(mismatch) printf("\n\nERROR: Mismatches between results from native execution and expected results.");
    else         printf("\n\nVerification SUCCEEDED. No mismatches were found.");
   
    // Free memory regions
    std::free(pFilters_DDR);
    pFilters_DDR = 0;
    
    std::free(pFiltersDW_DDR);
    pFilters_DDR = 0;
    
    std::free(pBiases_DDR);
    pBiases_DDR = 0;
    
    std::free(pBiasesDW_DDR);
    pBiases_DDR = 0;
    
    std::free(pIFMaps_DDR);
    pIFMaps_DDR = 0;
    
    std::free(pResidual_DDR);
    pResidual_DDR = 0;
    
    std::free(pOFMaps_Conv_DDR);
    pOFMaps_Conv_DDR = 0;
    
    std::free(pOFMaps_Pool_DDR);
    pOFMaps_Pool_DDR = 0;
    
    std::free(pOFMaps_Expected);
    pOFMaps_Expected = 0;
#endif

    return 0;
}
