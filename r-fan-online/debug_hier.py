import json, numpy as np

def convert_matrix(m_rf_row_major):
    m = np.array(m_rf_row_major).reshape(4,4)
    return m

def check_hierarchy():
    d = json.load(open('digger_clan_source/data.json', encoding='utf-8'))
    skeleton = d['skeleton']
    bone_by_name = {b['name']: b for b in skeleton}
    
    for b in skeleton:
        parent_name = b.get('parent', 'NULL')
        if parent_name in bone_by_name:
            p = bone_by_name[parent_name]
            p_wm = convert_matrix(p['world_matrix'])
            lm = convert_matrix(b['local_matrix'])
            wm = convert_matrix(b['world_matrix'])
            
            # test if p_wm * lm == wm
            calc_wm = lm @ p_wm  # since RF is row-major, parent * local might be local @ parent or parent @ local depending on API
            calc_wm2 = p_wm @ lm
            
            dist1 = np.linalg.norm(calc_wm - wm)
            dist2 = np.linalg.norm(calc_wm2 - wm)
            
            if dist1 > 0.1 and dist2 > 0.1:
                print(f"BONE {b['name']} mismatch! dist1={dist1:.2f}, dist2={dist2:.2f}")

check_hierarchy()
