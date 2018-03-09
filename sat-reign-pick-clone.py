#!/usr/bin/env python2
#-*- coding: utf-8 -*-
from __future__ import print_function

import itertools as it, operator as op, functools as ft
import lxml.builder as lb
from lxml import etree
import os, sys, re, yaml, pyaml


mods_dict = dict(
	s='speed',
	a='accuracy',
	h='health',
	hr='health-regen',
	e='energy',
	er='energy-regen' )
mods_dict_rev = dict(
	(v,k) for k,v in mods_dict.viewitems())

mods_mul = dict(
	s=0.01 )

mods_dict_xml = dict(
	s='SpeedOffset',
	a='AccuracyOffset',
	h='HealthOffset',
	hr='HealthRegenRate',
	e='EnergyMaxOffset',
	er='EnergyRegenRate' )
mods_dict_xml_rev = dict(
	(v,k) for k,v in mods_dict_xml.viewitems())

mods_degrade = dict(
	s=0.05,
	a=0.02,
	h=15,
	hr=0.15,
	e=5,
	er=0.15 )

clone_show = dict(
	id='Id',
	sex='Sex',
	clothes='WardrobeType',
	identity='IdentityId',
	seed='RandomSeed' )

agent_names={
	1: 'AGE_Soldier_01',
	2: 'AGE_Support_01',
	3: 'Agent_Assassin',
	4: 'Agent_Hacker' }

def x(el, path, one=True, null=False, t=False):
	if t: path += '/text()'
	val = el.xpath( './{}'.format(path),
		namespaces=dict(
			xsi='http://www.w3.org/2001/XMLSchema-instance',
			xsd='http://www.w3.org/2001/XMLSchema' ) )
	if one:
		if null and not val: return
		if len(val) != 1: raise ValueError(el, path, val)
		val = val[0]
		if re.search(r'/(@[-\w\d_]+|text\(\))$', path):
			val = val.encode('utf-8')
	return val

E = lb.E


def main(args=None):
	import argparse
	parser = argparse.ArgumentParser(
		description='Satellite Reign: pick clone id from xml by specified params.')
	parser.add_argument('mods',
		help='YAML with a list of attr modifiers'
				' that clone has OR agent id (integer 1-4).'
			' All keys must be lowercase, multi-word'
				' keys must have dashes instead of spaces.'
			' Can be shortened to first unique letters of words.')
	parser.add_argument('save', nargs='?',
		help='XML save game file. Stdin will be used, if not specified.')
	parser.add_argument('-p', '--print-clones', action='store_true',
		help='Print more info for each clone detected in source XML.')
	opts = parser.parse_args(sys.argv[1:] if args is None else args)

	mods_agent = opts.mods.isdigit() and int(opts.mods)

	if not mods_agent:
		mods = opts.mods
		if not mods.strip().startswith('{'): mods = '{{{}}}'.format(mods)
		mods = yaml.load(mods)
		for k in mods.keys():
			if k in mods_dict_rev:
				mods[mods_dict_rev[k]] = mods.pop(k)
		for k,v in mods.viewitems():
			if k in mods_mul: mods[k] = mods_mul[k] * v
		mods_xml = dict(
			(mods_dict_xml[k], v) for k,v in mods.viewitems() )

	src = open(opts.save, 'rb') if opts.save else sys.stdin
	xml = etree.parse(src)

	if mods_agent:
		agent_name = agent_names[mods_agent]
		for agent in xml.xpath('//m_Prefabs/SaveStateUID'):
			agent_ai = x( agent, 'm_Components/'
				'SaveComponentBase[@xsi:type="SaveStateAgentAI"]', null=True )
			if agent_ai is None\
				or x(agent_ai, 'm_AIEName', t=True) != agent_name: continue

			mods = list()
			for mod in x( agent_ai,
					'm_ClonedModifiers/ModifierData5L', False ):
				k, v = map(ft.partial(x, mod, t=True), ['m_Type', 'm_Ammount'])
				mods.append(
					E.CloneableModifier(
						E.m_ModifierData(
							E.m_Type(k), E.m_Ammount(v),
							E.m_TimeOut('0'), E.m_AmountModifier('NONE') ),
						E.m_DegradationPerClone(
							bytes(mods_degrade[mods_dict_xml_rev[k]]) ),
						E.m_MinimumValue('0') ) )
			assert mods
			print(etree.tostring(E.m_Modifiers(*mods), pretty_print=True))
			return
		raise ValueError(agent_name)

	clones_match, clones_all = dict(), dict()

	clone_list, = xml.xpath('//m_CloneablesList')
	for clone in x(clone_list, 'CloneableData', False):
		match, clone_mods = True, dict()
		clone_params = dict(
			(k, x(clone, v, t=True)) for k,v in clone_show.viewitems() )

		for mod in x(clone, 'm_Modifiers/CloneableModifier/m_ModifierData', False):
			k, v = map(ft.partial(x, mod, t=True), ['m_Type', 'm_Ammount'])
			v = float(v)
			if k not in mods_xml: match = False
			if abs(v - mods_xml.get(k, 0)) > 0.01: match = False
			clone_mods[k] = v

		if opts.print_clones:
			clone_repr = clone_params.copy()
			clone_repr['mods'], clone_repr_mods = dict(), clone_mods.copy()
			for k in clone_repr_mods.keys():
				if k in mods_dict_xml_rev:
					k_repr = mods_dict[mods_dict_xml_rev[k]]
					clone_repr['mods'][k_repr] = clone_repr_mods.pop(k)
			clone_repr['mods'].update(
				('raw-{}'.format(k), v) for k,v in clone_repr_mods.viewitems() )
			clones_all['clone-{}'.format(len(clones_all)+1)] = clone_repr

		if match:
			clones_match['clone-{}'.format(len(clones_match)+1)] = clone_params

	clones_match, clones_all = clones_match or None, clones_all or None

	res = dict(matched=clones_match)
	if opts.print_clones: res['found'] = clones_all
	pyaml.p(res)

if __name__ == '__main__': sys.exit(main())
