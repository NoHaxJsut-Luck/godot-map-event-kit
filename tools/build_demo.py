"""Create authored demo event resources. No downloaded or extracted game assets."""
from pathlib import Path
import json, math, struct, wave

root = Path(__file__).resolve().parents[1]
(root/'demo/events').mkdir(parents=True, exist_ok=True)
(root/'demo/audio').mkdir(parents=True, exist_ok=True)
def cmd(op, **kw): return {'op':op, **kw}
def text(s, speaker=''):return cmd('text',text=s,speaker=speaker)
def page(name, commands, visual='marker', condition='always', key='', value=True, trigger='interact'):
    return dict(name=name,condition=condition,key=key,value=value,trigger=trigger,visual=visual,commands=commands)
def save(name,title,pages):
    data=json.dumps(pages,ensure_ascii=False,indent=2)
    (root/f'demo/events/{name}.tres').write_text('[gd_resource type="Resource" script_class="MEKEventData" load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://addons/map_event_kit/core/event_data.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\ntitle = '+json.dumps(title,ensure_ascii=False)+'\npages = Array[Dictionary]('+data+')\n',encoding='utf-8')

save('chest','小院宝箱 · 独立开关',[
    page('未打开',[
        text('你掀开了宝箱。里面是一把铜钥匙和 10 枚金币。'),
        cmd('sound',path='res://demo/audio/chime.wav',volume_db=-10),
        cmd('set_switch',key='has_key',value=True),
        cmd('add_variable',key='coins',value=10),
        cmd('set_self_switch',key='A',value=True),
        text('获得铜钥匙 × 1，金币 +10。\n再来调查时，宝箱会记住自己已经被打开。')],visual='chest'),
    page('已经打开',[text('宝箱已经空了。\n你不会重复获得里面的物品。')],visual='chest_open',condition='self_switch',key='A')])
save('guide','守门人 · 选择与条件分支',[page('交谈',[
    text('欢迎来到苔石小院。遗迹的门需要一把铜钥匙。\n这里的对话、宝箱和门，都由事件列表驱动。','守门人'),
    cmd('choices',text='需要我给你一点提示吗？',options=['请给我提示','我自己探索'],key='guide_choice'),
    cmd('if_variable',key='guide_choice',value=0,compare='=='),
    cmd('if_switch',key='has_key',value=True),text('你已经拿到钥匙了！去小院北侧的遗迹门吧。','守门人'),
    cmd('else'),text('看看小路右侧的宝箱。按 E 或回车就能调查它。','守门人'),cmd('end'),
    cmd('else'),text('好奇心会为你指路。祝你探索愉快。','守门人'),cmd('end')],visual='npc')])
save('gate','遗迹门 · 开关检测与传送',[page('开门',[
    cmd('if_switch',key='has_key',value=True),
    text('铜钥匙恰好与锁孔吻合。\n通往遗迹的门打开了。'),cmd('wait',seconds=0.15),
    cmd('transfer',scene='res://demo/ruins.tscn',spawn='Arrival'),
    cmd('else'),text('门锁着。\n需要先找到铜钥匙。'),cmd('end')],visual='door')])
save('return','返回小院',[page('返回',[cmd('transfer',scene='res://demo/courtyard.tscn',spawn='FromRuins')],visual='portal')])
save('arrival','抵达遗迹 · 自动事件',[
    page('首次抵达',[
        cmd('set_switch',key='visited_ruins',value=True),
        text('你抵达了静谧遗迹。\n这是进入地图时自动执行的事件。'),
        text('可以保存后重启，再读取进度。\n返回小院后，宝箱的独立开关仍然有效。')],trigger='autorun'),
    page('已经抵达',[],condition='switch',key='visited_ruins')])
save('sign','路牌 · 接触触发',[page('阅读',[text('路牌：北侧是遗迹，东侧藏着一只旧宝箱。\n离开这块区域后，再走近可以重新触发。')],trigger='touch')])

def scene(name,events):
    refs=['[ext_resource type="Script" path="res://demo/world.gd" id="1"]','[ext_resource type="Script" path="res://demo/player.gd" id="2"]','[ext_resource type="Script" path="res://addons/map_event_kit/runtime/map_event.gd" id="3"]']
    for i,e in enumerate(events,4):refs.append(f'[ext_resource type="Resource" path="res://demo/events/{e[0]}.tres" id="{i}"]')
    s=f'[gd_scene load_steps={len(refs)+2} format=3]\n\n'+'\n'.join(refs)+'\n\n'
    s+='[sub_resource type="CircleShape2D" id="PlayerShape"]\nradius = 11.0\n\n'
    s+='[node name="'+name.capitalize()+'" type="Node2D"]\nscript = ExtResource("1")\nregion = "'+name+'"\n\n'
    s+='[node name="Player" type="CharacterBody2D" parent="."]\nposition = Vector2(235, 396)\nscript = ExtResource("2")\n\n'
    s+='[node name="CollisionShape2D" type="CollisionShape2D" parent="Player"]\nshape = SubResource("PlayerShape")\n\n'
    s+='[node name="Arrival" type="Marker2D" parent="."]\nposition = Vector2(220, 398)\n\n'
    s+='[node name="FromRuins" type="Marker2D" parent="."]\nposition = Vector2(616, 345)\n\n'
    for i,(asset,node,display,x,y,color) in enumerate(events,4):
        s+=f'[node name="{node}" type="Node2D" parent="."]\nposition = Vector2({x}, {y})\nscript = ExtResource("3")\nevent_id = "{asset}_01"\ndisplay_name = "{display}"\ndata = ExtResource("{i}")\nmarker_color = Color({color})\n\n'
    (root/f'demo/{name}.tscn').write_text(s,encoding='utf-8')
scene('courtyard',[('guide','Guide','守门人',345,353,'0.81, 0.64, 0.4, 1'),('chest','Chest','旧宝箱',755,347,'0.8, 0.7, 0.4, 1'),('gate','Gate','遗迹门',615,271,'0.46, 0.77, 0.67, 1'),('sign','Sign','路牌',450,475,'0.5, 0.65, 0.5, 1')])
scene('ruins',[('return','Return','返回小院',145,355,'0.43, 0.7, 0.8, 1'),('arrival','ArrivalEvent','回响石碑',615,300,'0.6, 0.8, 0.8, 1')])
with wave.open(str(root/'demo/audio/chime.wav'),'wb') as w:
    w.setnchannels(1);w.setsampwidth(2);w.setframerate(22050)
    w.writeframes(b''.join(struct.pack('<h',int(10000*math.exp(-t/5000)*math.sin(2*math.pi*(660 if t<5500 else 880)*t/22050))) for t in range(11025)))
print('Created 6 event resources, 2 scenes, and an original synthesized chime.')
