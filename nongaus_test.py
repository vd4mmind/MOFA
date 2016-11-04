
from __future__ import division
from time import time
import cPickle as pkl
import scipy as s
import os
import scipy.special as special
import scipy.stats as stats
import numpy.linalg  as linalg

from simulate import Simulate
from BayesNet import BayesNet
from utils import save_npy

# Import manually defined updates
from multiview_nodes import *
from seeger_nodes import Binomial_PseudoY_Node, Poisson_PseudoY_Node, Bernoulli_PseudoY_Node, Zeta_Node
from local_nodes import Local_Node, Observed_Local_Node
from updates import Y_Node, Alpha_Node, W_Node, Tau_Node, Z_Node, Y_Node

"""
- Update Y with gaussian, what happens?
- Permutation test for latenet variables
- Multiple runs
"""

###################
## Generate data ##
###################

# Define dimensionalities
M = 3
N = 100
D = s.asarray([100,100,100])
K = 6


## Simulate data  ##
data = {}
tmp = Simulate(M=M, N=N, D=D, K=K)

data['Z'] = s.zeros((N,K))
data['Z'][:,0] = s.sin(s.arange(N)/(N/20))
data['Z'][:,1] = s.cos(s.arange(N)/(N/20))
data['Z'][:,2] = 2*(s.arange(N)/N-0.5)
data['Z'][:,3] = stats.norm.rvs(loc=0, scale=1, size=N)
data['Z'][:,4] = stats.norm.rvs(loc=0, scale=1, size=N)
data['Z'][:,5] = stats.norm.rvs(loc=0, scale=1, size=N)

data['alpha'] = s.zeros((M,K))
data['alpha'][0,:] = [1,1,1e6,1,1e6,1e6]
data['alpha'][1,:] = [1,1e6,1,1e6,1,1e6]
data['alpha'][2,:] = [1e6,1,1,1e6,1e6,1]

data['W'], _ = tmp.initW_ard(alpha=data['alpha'])
data['mu'] = [ s.zeros(D[m]) for m in xrange(M)]
# data['tau']= [ s.ones(D[m])*1000 for m in xrange(M) ]
data['tau']= [ stats.uniform.rvs(loc=0.1,scale=3,size=D[m]) for m in xrange(M) ]
Y_gaussian = tmp.generateData(W=data['W'], Z=data['Z'], Tau=data['tau'], Mu=data['mu'], likelihood="gaussian")
# Y_poisson = tmp.generateData(W=data['W'], Z=data['Z'], Tau=data['tau'], Mu=data['mu'], likelihood="poisson")
# Y_bernoulli = tmp.generateData(W=data['W'], Z=data['Z'], Tau=data['tau'], Mu=data['mu'], likelihood="bernoulli")
# Y_binomial = tmp.generateData(W=data['W'], Z=data['Z'], Tau=data['tau'], Mu=data['mu'], likelihood="binomial", min_trials=10, max_trials=50)

# data["Y"] = ( Y_gaussian[0], Y_poisson[1], Y_bernoulli[2] )
# data["Y"] = Y_bernoulli
# data["Y"] = Y_poisson
# data["Y"] = Y_binomial
data["Y"] = Y_gaussian

M_bernoulli = []
M_poisson = []
M_gaussian = [0,1,2]
M_binomial = []

# M_bernoulli = []
# M_poisson = []
# M_gaussian = []
# M_binomial = [0,1,2]

#################################
## Initialise Bayesian Network ##
#################################

net = BayesNet()

# Define initial number of latent variables
K = 20

# Define model dimensionalities
net.dim["M"] = M
net.dim["N"] = N
net.dim["D"] = D
net.dim["K"] = K

###############
## Add nodes ##
###############

# Z (variational node)
Z_qmean = s.stats.norm.rvs(loc=0, scale=1, size=(N,K))
Z_qcov = s.repeat(s.eye(K)[None,:,:],N,0)
Z = Z_Node(dim=(N,K), qmean=Z_qmean, qcov=Z_qcov)
Z.updateExpectations()


# alpha (variational node)
alpha_list = [None]*M
alpha_pa = 1e-14
alpha_pb = 1e-14
alpha_qb = s.ones(K)
alpha_qE = s.ones(K)*100
for m in xrange(M):
	alpha_qa = alpha_pa + s.ones(K)*D[m]/2
	alpha_list[m] = Alpha_Node(dim=(K,), pa=alpha_pa, pb=alpha_pb, qa=alpha_qa[m], qb=alpha_qb, qE=alpha_qE)
alpha = Multiview_Variational_Node((K,)*M, *alpha_list)


# W (variational node)
W_list = [None]*M
for m in xrange(M):
	W_qmean = s.stats.norm.rvs(loc=0, scale=1, size=(D[m],K))
	W_qcov = s.repeat(a=s.eye(K)[None,:,:], repeats=D[m] ,axis=0)
	W_list[m] = W_Node(dim=(D[m],K), qmean=W_qmean, qcov=W_qcov, qE=W_qmean)
W = Multiview_Variational_Node(M, *W_list)



# tau/kappa (mixed node)
tau_list = [None]*M
for m in xrange(M):
	if m in M_poisson:
		tmp = 0.25 + 0.17*s.amax(data["Y"][m],axis=0) 
		tau_list[m] = Observed_Local_Node(dim=(D[m],), value=tmp)
	elif m in M_bernoulli:
		tmp = s.ones(D[m])*0.25 
		tau_list[m] = Observed_Local_Node(dim=(D[m],), value=tmp)
	elif m in M_binomial:
		tmp = 0.25*s.amax(data["Y"]["tot"][m],axis=0)
		tau_list[m] = Observed_Local_Node(dim=(D[m],), value=tmp)
	elif m in M_gaussian:
		tau_pa = 1e-14
		tau_pb = 1e-14
		tau_qa = tau_pa + s.ones(D[m])*N/2
		tau_qb = s.zeros(D[m])
		tau_qE = s.zeros(D[m]) + 100
		tau_list[m] = Tau_Node(dim=(D[m],), pa=tau_pa, pb=tau_pb, qa=tau_qa, qb=tau_qb, qE=tau_qE)
tau = Multiview_Mixed_Node(M,*tau_list)


# zeta (local node)
# not initialised since it is the first update
Zeta_list = [None]*M
for m in xrange(M):
	if m not in M_gaussian:
		Zeta_list[m] = Zeta_Node(dim=(N,D[m]), initial_value=None) 
	else:
		Zeta_list[m] = None
Zeta = Multiview_Local_Node(M, *Zeta_list)


# Y/Yhat (mixed node)
Y_list = [None]*M
for m in xrange(M):
	if m in M_gaussian:
		Y_list[m] = Y_Node(dim=(N,D[m]), obs=data['Y'][m])
	elif m in M_poisson:
		Y_list[m] = Poisson_PseudoY_Node(dim=(N,D[m]), obs=data['Y'][m], E=None)
	elif m in M_bernoulli:
		Y_list[m] = Bernoulli_PseudoY_Node(dim=(N,D[m]), obs=data['Y'][m], E=None)
	elif m in M_binomial:
		Y_list[m] = Binomial_PseudoY_Node(dim=(N,D[m]), tot=data['Y']["tot"][m], obs=data['Y']["obs"][m], E=None)
Y = Multiview_Mixed_Node(M, *Y_list)


############################
## Define Markov Blankets ##
############################

Z.addMarkovBlanket(W=W, tau=tau, Y=Y)
for m in xrange(M):
	alpha.nodes[m].addMarkovBlanket(W=W.nodes[m])
	W.nodes[m].addMarkovBlanket(Z=Z, tau=tau.nodes[m], alpha=alpha.nodes[m], Y=Y.nodes[m])
	if m in M_gaussian:
		Y.nodes[m].addMarkovBlanket(Z=Z, W=W.nodes[m], tau=tau.nodes[m])
		tau.nodes[m].addMarkovBlanket(W=W.nodes[m], Z=Z, Y=Y.nodes[m])
	else:
		Zeta.nodes[m].addMarkovBlanket(Z=Z, W=W.nodes[m])
		Y.nodes[m].addMarkovBlanket(Z=Z, W=W.nodes[m], kappa=tau.nodes[m], zeta=Zeta.nodes[m])

##################################
## Add the nodes to the network ##
##################################

net.addNodes(Zeta=Zeta, W=W, tau=tau, Z=Z, Y=Y, alpha=alpha)

# Define update schedule
schedule = ["Zeta","Y","W","Z","alpha","tau"]
net.setSchedule(schedule)

#############################
## Define training options ##
#############################

options = {}
options['maxiter'] = 2000
options['tolerance'] = 1E-2
options['forceiter'] = True
# options['elbofreq'] = options['maxiter']+1
options['elbofreq'] = 1
options['dropK'] = True
options['dropK_threshold'] = 0.01
options['savefreq'] = options['maxiter']+1
options['savefolder'] = "/tmp/test"
options['verbosity'] = 2
net.options = options


####################
## Start training ##
####################


params, expectations = net.iterate()

exit()

##################
## Save results ##
##################

# Save parameters
p_outfolder = "/tmp/params"
for node,a in params.iteritems():
	for param_name,values in a.iteritems():
		prefix = "%s_%s" % (node,param_name)
		save_npy(outdir=p_outfolder, outprefix=prefix, data=values)
# os.system("gzip -f %s/*" % p_outfolder)

# Save expectations
e_outfolder = "/tmp/expectations"
for node,a in expectations.iteritems():
	for moment_name,values in a.iteritems():
		prefix = "%s_%s" % (node,moment_name)
		save_npy(outdir=e_outfolder, outprefix=prefix, data=values)
# os.system("gzip -f %s/*" % e_outfolder)