all_systems=centos debian ubuntu fednew suseold susenew
# Versions to test, tag prefixes and docker templates
# Fedora 20 and 21 removed, package feed broken hopelessly.
centos_ver=6 7
centos_tag=centos
centos_pac=redhat

debian_ver=7 8 9
debian_tag=debian
debian_pac=debian

#fedold_ver=20 21
#fedold_tag=fedora
#fedold_pac=redhat

fednew_ver=22 24 27 29 31 rawhide
fednew_tag=fedora
fednew_pac=fedora

suseold_ver=13.2 42.1 # 42.2
suseold_tag=opensuse/amd64
suseold_pac=suse

susenew_ver=42.3 15.1
susenew_tag=opensuse/leap
susenew_pac=suse

ubuntu_ver=14.04 16.04 18.04 18.10 19.04
ubuntu_tag=ubuntu
ubuntu_pac=debian

# Do not run full MKL install under test, too heavyweight. Docs is enough.
command=./install_mkl.sh intel-mkl-doc

#------------------------------------------------------------------------------

tstprefix=test_install_mkl
label=ai.smartaction.$(tstprefix)

ifndef subsys

# Top makefile invocation

sumo=$(foreach f,$(all_systems),$(foreach v,$($(f)_ver),$(f)+$(v)))

.PHONY: all clean veryclean $(sumo)
all: $(sumo) ;
$(sumo) : % : ; @$(MAKE) --no-print-directory all subsys="$@"

clean:
	rm -f *.log; \
	docker container rm -f $$(docker container ps --quiet --all --filter=label=$(label)) &>/dev/null; \
	docker image prune -f &>/dev/null; true

veryclean: clean
	docker image rm -f $$(docker image ls --quiet --all --filter=label=$(label)) &>/dev/null || true

else

# Submake invocation. Figure out what to pull and how to build.
sys=$(word 1,$(subst +, ,$(subsys)))
ver=$(word 2,$(subst +, ,$(subsys)))

pmstyle=$($(sys)_pac)
dockerfile=Dockerfile.$(pmstyle)
srcimage=$($(sys)_tag):$(ver)
dstimage=$(tstprefix)-$(sys)_$(ver)
testid=$(sys)_$(ver)

.PHONY: all image tests testexpect ;

all: tests ;

image: $(dockerfile)
	@echo >&2 "Building image $(dstimage)"
	@if docker build -f $(dockerfile) -t "$(dstimage)" --label "$(label)=t" \
	        --build-arg="base=$(srcimage)" . &> build-$(testid).log ; then \
	  rm build-$(testid).log; \
	else \
	  mv build-$(testid).log FAIL-build-$(testid).log; \
	  echo >&2 "ERROR: Image build for $(testid) failed. Check FAILED-build-$(testid).log"; fi

tests: image testexpect ;

# We are using the same name for image and container.
testexpect: image
	@-docker container rm --force $(dstimage) &>/dev/null || true
	@if expect -f install_mkl.expect -c \
	   'spawn docker run --rm --label "$(label)=t" --name $(dstimage) -it $(dstimage) "$(command)"' \
	     $(pmstyle) &>test-$(testid).log; \
         then mv test-$(testid).log SUCCESS-test-$(testid).log; \
	      echo >&2 "SUCCESS: $(testid)"; \
	 else mv test-$(testid).log FAIL-test-$(testid).log; \
	      echo >&2 "FAILURE: $(testid): check FAIL-test-$(testid).log "; fi
	@-docker container rm --force $(dstimage) &>/dev/null || true

endif
