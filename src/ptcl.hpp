#pragma once
#include<particle_simulator.hpp>
#include"usr_define.hpp"

const PS::F64 SAFTY_FACTOR_FOR_SEARCH = 0.99;
//const PS::F64 SAFTY_FACTOR_FOR_SEARCH_SQ = SAFTY_FACTOR_FOR_SEARCH * SAFTY_FACTOR_FOR_SEARCH;
//const PS::F64 SAFTY_OFFSET_FOR_SEARCH = 1e-7;
//const PS::F64 SAFTY_OFFSET_FOR_SEARCH = 0.0;

class Ptcl: public ParticleBase{
public:
    /*
                single           c.m.                       members               unused        suppressed c.m.
      id         id          id of first member (-)            id                   -1          id of previous c.m. (-)
      status      0          member number                  c.m. adr (-)            -1            -20 
      mass_bk     0             mass                         mass                 unknown       unknown
                 fake members                                                                            
                id_offset+id*n_split+iphase                                             
                1. first component member number 2. second. 3. i_cluster+1, 4. i_group+1, others: (c.m.id<<ID_PHASE_SHIFT)|i
                  binary parameters                                                 

      PS: mass_bk is used to store perturber force in searchpart
          suppressed c.m. is set in HermiteIntegrator.removePtclList
     */
    PS::F64 r_search;
    PS::F64 mass_bk;
    PS::S64 id;
    PS::S64 status;
    static PS::F64 search_factor;
    static PS::F64 r_search_min;
    static PS::F64 mean_mass_inv;

    Ptcl(): id(-10), status(-10) {}

    template<class Tptcl>
    Ptcl(const Tptcl& _p) { Ptcl::DataCopy(_p);  }

    template<class Tptcl>
    Ptcl(const Tptcl& _p, const PS::F64 _r_search, const PS::F64 _mass_bk, const PS::S64 _id, const PS::S64 _status): ParticleBase(_p), r_search(_r_search), mass_bk(_mass_bk), id(_id), status(_status)  {}

    template<class Tptcl>
    void DataCopy(const Tptcl& _p) {
        ParticleBase::DataCopy(_p);
        r_search = _p.r_search;
        mass_bk  = _p.mass_bk;
        id       = _p.id;
        status   = _p.status;
    }

    template<class Tptcl>
    Ptcl& operator = (const Tptcl& _p) {
        Ptcl::DataCopy(_p);
        return *this;
    }

    void print(std::ostream & _fout){
        ParticleBase::print(_fout);
        _fout<<" r_search="<<r_search
             <<" mass_bk="<<mass_bk
             <<" id="<<id
             <<" status="<<status;
    }

    void writeAscii(FILE* _fout) const{
        ParticleBase::writeAscii(_fout);
        fprintf(_fout, "%26.17e %26.17e %lld %lld ", 
                this->r_search, this->mass_bk, this->id, this->status);
    }

    void writeBinary(FILE* _fin) const{
        ParticleBase::writeBinary(_fin);
        fwrite(&(this->r_search), sizeof(PS::F64), 4, _fin);
    }

    void readAscii(FILE* _fin) {
        ParticleBase::readAscii(_fin);
        PS::S64 rcount=fscanf(_fin, "%lf %lf %lld %lld ",
                              &this->r_search, &this->mass_bk, &this->id, &this->status);
        if (rcount<4) {
            std::cerr<<"Error: Data reading fails! requiring data number is 4, only obtain "<<rcount<<".\n";
            abort();
        }
    }

    void readBinary(FILE* _fin) {
        ParticleBase::readBinary(_fin);
        size_t rcount = fread(&(this->r_search), sizeof(PS::F64), 4, _fin);
        if (rcount<4) {
            std::cerr<<"Error: Data reading fails! requiring data number is 4, only obtain "<<rcount<<".\n";
            abort();
        }
    }

    void calcRSearch(const PS::F64 _dt_tree) {
        r_search = std::max(std::sqrt(vel*vel)*_dt_tree*search_factor, r_search_min);
        //r_search = std::max(std::sqrt(vel*vel)*dt_tree*search_factor, std::sqrt(mass*mean_mass_inv)*r_search_min);
#ifdef HARD_DEBUG
        assert(r_search>0);
#endif
    }

    void dump(FILE *_fout) {
        fwrite(this, sizeof(*this),1,_fout);
    }

    void read(FILE *_fin) {
        size_t rcount = fread(this, sizeof(*this),1,_fin);
        if (rcount<1) {
            std::cerr<<"Error: Data reading fails! requiring data number is 1, only obtain "<<rcount<<".\n";
            abort();
        }
    }
};

PS::F64 Ptcl::r_search_min = 0.0;
PS::F64 Ptcl::search_factor= 0.0;
PS::F64 Ptcl::mean_mass_inv= 0.0; // mean mass inverse
