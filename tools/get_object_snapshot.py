#!/usr/bin/env python3

import numpy as np
import sys
import petar
import getopt

if __name__ == '__main__':

    filename_prefix='data'
    snap_type='origin'
    snapshot_format='ascii'
    interrupt_mode='bse'

    def usage():
        print("A tool to gether objects from a list of snapshots into one file. Only work when interrupt-mode is bse")
        print("   The tool scan snapshots in the list and select all singles or binaries with the provided type")
        print("   then save the data into a new file.")
        print("   An additional column, time, will be added, which is obtain from the header of snapshots.")
        print("   Before reading the output file by using Python module petar.Particle or petar.Binary, ")
        print("   make sure to use addNewMember('time', np.array([]).astype(float)) first.")
        print("   Output file has the name style of [prefix].[object_typename].[origin|single|binary]")
        print("        prefix is defined in the option -p;")
        print("        object_typename is defined by SSE star type;")
        print("        origin, single or binary represent the origin snapshots from PeTar, generated single or binary from petar.data.process, respectively")
        print("Usage: petar.get.object.snap [options] type [typeb] data_filename")
        print("type(type2): SSE stellar type (e.g. BH, MS) to select target for saving, when the snapshot are binary, typeb for secondary components are needed")
        print("   The argument can be a combination of multiple types by [type1]_[type2]...")
        print("   For exmaple, 'BH_MS' indicates to find both BH and MS types.")
        print("   If 'no' is added in front of type name, it indicate to select all types except the given one.")
        print("   For exmaple, 'noBH' indicates to find non-BH objects.")
        print("   The base SSE star type names are shown below:")
        print("         LMS:  deeply or fully convective low mass MS star [0]")
        print("         MS:   Main Sequence star [1]")
        print("         HG:   Hertzsprung Gap [2]")
        print("         GB:   First Giant Branch [3]")
        print("         CHeB: Core Helium Burning [4]")
        print("         FAGB: First Asymptotic Giant Branch [5]")
        print("         SAGB: Second Asymptotic Giant Branch [6]")
        print("         HeMS: Main Sequence Naked Helium star [7]")
        print("         HeHG: Hertzsprung Gap Naked Helium star [8]")
        print("         HeGB: Giant Branch Naked Helium star [9]")
        print("         HeWD: Helium White Dwarf [10]")
        print("         COWD: Carbon/Oxygen White Dwarf [11]")
        print("         ONWD: Oxygen/Neon White Dwarf [12]")
        print("         NS:   Neutron Star [13]")
        print("         BH:   Black Hole [14]")
        print("         SN:   Massless Supernova [15]")
        print("data_filename: A list of snapshot data path with the original filenames (no suffixes of '.single|.binary')")
        print("               each line for one snapshot")
        print("option:")
        print("  -h(--help): help")        
        print("  -p(--filename-prefix): prefix of output file name: data")
        print("  -f(--snapshot-type): indicate the snapshot type to read: origin, single, binary (origin)")
        print("               Notice that the data_filename is the original snapshot name generated by PeTar")
        print("               When single|binary are used, the corresponding snapshots generated by petar.data.process are used")
        print("               But the original snapshots are still needed to read the header (time)")
        print("  -i(--interrupt-mode): the interruption mode used in petar, choices: bse (bse)")
        print("  -t(--external-mode): external mode used in petar, choices: galpy, no (no)")
        print("  -s(--snapshot-format): snapshot data format: binary, ascii; only for reading original snapshots (ascii)")
        print("  -B(--full-binary): this indicate the snapshot contain full binary information (when petar.data.process -B is used)")

    try:
        shortargs = 'p:f:Bt:i:s:h'
        longargs = ['snapshot-type','full-binary','filename-prefix=','external-mode=','interrupt-mode=','snapshot-format=','help']
        opts,remainder= getopt.getopt( sys.argv[1:], shortargs, longargs)

        kwargs=dict()
        for opt,arg in opts:
            if opt in ('-h','--help'):
                usage()
                sys.exit(1)
            elif opt in ('-p','--filename-prefix'):
                filename_prefix = arg
            elif opt in ('-f','--snapshot-type'):
                snap_type = arg
            elif opt in ('-B','--full-binary'):
                kwargs['simple_binary'] = False
            elif opt in ('-i','--interrupt-mode'):
                interrupt_mode = arg
            elif opt in ('-t','--external-mode'):
                kwargs['external_mode'] = arg
            elif opt in ('-s','--snapshot-format'):
                snapshot_format = arg
                kwargs['snapshot_format'] = arg
                
            else:
                assert False, "unhandeld option"

    except getopt.GetoptError:
        print('getopt error!')
        usage()
        sys.exit(1)

    sse_type = remainder[0]
    sse_type2 = ''
    filename = remainder[1]
    if (snap_type=='binary'):
        sse_type2 = remainder[1]
        filename = remainder[2]

    kwargs['filename_prefix'] = filename_prefix
    kwargs['interrupt_mode'] = interrupt_mode

    for key, item in kwargs.items(): print(key,':',item)

    fl = open(filename,'r')
    file_list = fl.read()
    path_list = file_list.splitlines()

    output_data = petar.Particle(**kwargs)
    p1 = petar.Particle(**kwargs)
    p2 = petar.Particle(**kwargs)
    if (snap_type=='binary'):
        output_data = petar.Binary(p1,p2,**kwargs)
    output_data.addNewMember('time',np.array([]).astype(float))

    def select_type(_data, _type):
        sel = np.zeros(_data.size).astype(bool)
        for subtype in _type.split('_'):
            if (subtype[:2]=='no'):
                type_index = petar.BSE_STAR_TYPE_INDEX[subtype[2:]]
                sel = sel | (_data.star.type!=type_index)
            else:
                type_index = petar.BSE_STAR_TYPE_INDEX[subtype]
                sel = sel | (_data.star.type==type_index)
        return sel

    select_data=[]
    for path in path_list:
        print('process ',path)
        header_temp = petar.PeTarDataHeader(path, **kwargs)
        time = header_temp.time
        sel = np.array([])
        if (snap_type=='binary'):
            p1_temp = petar.Particle(**kwargs)
            p2_temp = petar.Particle(**kwargs)
            data_temp=petar.Binary(p1_temp, p2_temp, **kwargs)
            data_temp.loadtxt(path+'.binary')
            sel1 = select_type(data_temp.p1, sse_type)
            sel2 = select_type(data_temp.p2, sse_type2)
            sel = sel1 & sel2
            
            sel1 = select_type(data_temp.p1, sse_type2)
            sel2 = select_type(data_temp.p2, sse_type)
            sel = sel | (sel1 & sel2)
            
        else:
            data_temp=petar.Particle(**kwargs)
            if (snap_type=='origin'):
                if (snapshot_format=='ascii'): data_temp.loadtxt(path, skiprows=1)
                else: data_temp.fromfile(path, offset=petar.HEADER_OFFSET)
            else:
                data_temp.loadtxt(path)
            sel = select_type(data_temp, sse_type)

        data_sel = data_temp[sel]
        data_sel.addNewMember('time',np.ones(data_sel.size)*time)
        select_data.append(data_sel)

    output_data=petar.join(*select_data)

    filename_out = filename_prefix+'.'+sse_type+'.'+snap_type
    if (snap_type=='binary'):     filename_out = filename_prefix+'.'+sse_type+'.'+sse_type2+'.'+snap_type
    print('Output file: ',filename_out)

    output_data.savetxt(filename_out)