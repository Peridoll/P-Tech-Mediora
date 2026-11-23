from pathlib import Path
import unittest
from lupa.lua54 import LuaRuntime

ROOT=Path(__file__).resolve().parents[2]

class BagStyleTest(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime()
        self.lua.execute('''
        jobs={};events={};requests={};removed=0;hookCount=0;convars={}
        function CreateThread(fn) jobs[#jobs+1]=fn end
        function Wait() end
        function GetResourceState() return 'started' end
        function AddEventHandler(name,fn) events[name]=fn end
        function GetConvar(name,default) return convars[name] or default end
        function PerformHttpRequest(url,callback,method)
            assert(method=='HEAD');requests[#requests+1]={url=url,callback=callback}
        end
        json={decode=function(raw) return {} end}
        exports={ox_inventory={
            setContainerProperties=function() end,
            registerHook=function(_,event,fn,options)
                if event=='openInventory' then assert(options.typeFilter.container);return 'capacity-hook' end
                assert(event=='createItem' and options.itemFilter.pmediora_medicalbag==true)
                hook=fn;hookCount=hookCount+1;return 'appearance-hook'
            end,
            removeHooks=function(_,id) if id=='appearance-hook' then removed=removed+1 else assert(id=='capacity-hook') end end,
        }}
        function runJobs() while #jobs>0 do table.remove(jobs,1)() end end
        ''')
        self.lua.execute((ROOT/'config.lua').read_text(encoding='utf-8'))
        self.lua.execute((ROOT/'main/server/containers.lua').read_text(encoding='utf-8'))
        self.lua.execute('runJobs()')

    def test_all_four_new_variants_and_existing_metadata_kept(self):
        self.lua.execute('''
        local expected={1,2,3,4}
        for index,style in ipairs(expected) do
            local draws=0
            math.random=function(a,b) assert(a==1 and b==4);draws=draws+1;return index end
            local meta={container='unique-'..style,size={24,30000},weight=1234}
            local result=hook({metadata=meta})
            assert(result==meta and result.medicalBagVariant==style)
            assert(result.container=='unique-'..style and result.size[1]==24 and result.weight==1234)
            assert(result.imageurl:find('nui://ptech_mediora_medical/',1,true)==1)
            assert(result.imageurl:find('pmediora_bag'..style..'.png',1,true))
            -- Copy represents a DB round-trip / transfer to another player's inventory.
            local restored={container=result.container,size={24,30000},medicalBagVariant=result.medicalBagVariant}
            local transferred=hook({metadata=restored})
            assert(transferred.medicalBagVariant==style and transferred.container==result.container and draws==1)
        end
        ''')

    def test_only_verified_remote_png_replaces_local_fallback(self):
        self.lua.execute('''
        assert(#requests==4)
        requests[1].callback(404,'',{})
        requests[2].callback(200,'',{['content-type']='text/html'})
        requests[3].callback(200,'',{['content-type']='image/png'})
        assert(hook({metadata={medicalBagVariant=1}}).imageurl:find('nui://',1,true)==1)
        assert(hook({metadata={medicalBagVariant=2}}).imageurl:find('nui://',1,true)==1)
        assert(hook({metadata={medicalBagVariant=3}}).imageurl==requests[3].url)
        ''')

    def test_restarts_keep_selection_and_ignore_previous_http_responses(self):
        self.lua.execute('''
        local old=requests[1]
        events.onResourceStart('ox_inventory');runJobs()
        assert(hookCount==2 and removed==1)
        old.callback(200,'',{['content-type']='image/png'})
        local meta=hook({metadata={container='saved',medicalBagVariant=1}})
        assert(meta.imageurl:find('nui://',1,true)==1 and meta.medicalBagVariant==1 and meta.container=='saved')
        ''')

    def test_unapproved_remote_host_uses_packaged_icons(self):
        self.lua.execute('''
        convars['inventory:webhook']='configured'
        events.onResourceStart('ox_inventory');runJobs()
        assert(#requests==4,'no requests when ox_inventory would reject remote URLs')
        assert(hook({metadata={medicalBagVariant=4}}).imageurl:find('nui://',1,true)==1)
        ''')
